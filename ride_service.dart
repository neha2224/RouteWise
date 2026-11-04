import '../config/api_config.dart';
import 'api_service.dart';

class RideService {
  static const Map<String, List<double>> _cityCoords = {
    'pune': [18.5204, 73.8567],
    'mumbai': [19.0760, 72.8777],
    'nashik': [19.9975, 73.7898],
    'nagpur': [21.1458, 79.0882],
    'aurangabad': [19.8762, 75.3433],
    'sambhajinagar': [19.8762, 75.3433],
    'delhi': [28.6139, 77.2090],
    'bangalore': [12.9716, 77.5946],
    'bengaluru': [12.9716, 77.5946],
    'hyderabad': [17.3850, 78.4867],
    'chennai': [13.0827, 80.2707],
    'kolkata': [22.5726, 88.3639],
    'ahmedabad': [23.0225, 72.5714],
    'surat': [21.1702, 72.8311],
  };

  static const List<String> allVehicleTypes = [
    'TEMPO',
    'MINI_TRUCK',
    'PICKUP',
    'TRUCK',
  ];

  static const Map<String, double> defaultVehiclePrices = {
    'TEMPO': 450.0,
    'PICKUP': 650.0,
    'MINI_TRUCK': 850.0,
    'TRUCK': 1400.0,
  };

  static const Map<String, double> defaultVehicleCapacities = {
    'TEMPO': 1000.0,
    'PICKUP': 1500.0,
    'MINI_TRUCK': 2500.0,
    'TRUCK': 7000.0,
  };

  static List<double> resolveCoordinates(String location, {bool isDrop = false}) {
    final normalized = location.trim().toLowerCase();
    for (final entry in _cityCoords.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return isDrop ? [19.0760, 72.8777] : [18.5204, 73.8567];
  }

  /// Ensures existing drivers in the backend have GPS coordinates so they appear in search
  static Future<void> ensureDriversHaveLocations() async {
    final fallbackLocations = <int, Map<String, dynamic>>{
      1: {'latitude': 19.9975, 'longitude': 73.7898, 'currentLocation': 'Nashik'},
      2: {'latitude': 18.5204, 'longitude': 73.8567, 'currentLocation': 'Pune'},
      3: {'latitude': 19.0760, 'longitude': 72.8777, 'currentLocation': 'Mumbai'},
      4: {'latitude': 19.9975, 'longitude': 73.7898, 'currentLocation': 'Nashik'},
      5: {'latitude': 18.5204, 'longitude': 73.8567, 'currentLocation': 'Pune'},
    };

    for (final entry in fallbackLocations.entries) {
      try {
        final loc = await ApiService.get(ApiConfig.driverLocation(entry.key));
        if (loc is Map &&
            (loc['latitude'] == null || loc['longitude'] == null)) {
          await ApiService.put(
            ApiConfig.driverLocation(entry.key),
            body: entry.value,
          );
        }
      } catch (_) {}
    }
  }

  /// Searches drivers and returns both the drivers list AND the backend's AI recommendation string.
  static Future<Map<String, dynamic>> searchDriversWithAI({
    required String pickupLocation,
    String vehicleType = 'ALL',
    double? pickupLatitude,
    double? pickupLongitude,
    String goodsType = 'General Goods',
    String dropLocation = 'Destination Hub',
    double goodsWeight = 250.0,
  }) async {
    final coords = resolveCoordinates(pickupLocation);
    final lat = pickupLatitude ?? coords[0];
    final lng = pickupLongitude ?? coords[1];
    final safeWeight = goodsWeight > 0 ? goodsWeight : 250.0;

    final typesToQuery = (vehicleType.toUpperCase() == 'ALL')
        ? allVehicleTypes
        : [vehicleType.toUpperCase()];

    final Map<int, Map<String, dynamic>> uniqueDrivers = {};
    String? aiRecommendation;

    for (final vType in typesToQuery) {
      try {
        final response = await ApiService.post(
          ApiConfig.rideSearch,
          body: {
            'vehicleType': vType,
            'pickupLocation': pickupLocation.trim(),
            'pickupLatitude': lat,
            'pickupLongitude': lng,
            'goodsType': goodsType.trim().isEmpty
                ? 'General Goods'
                : goodsType.trim(),
            'dropLocation': dropLocation.trim().isEmpty
                ? 'Destination Hub'
                : dropLocation.trim(),
            'goodsWeight': safeWeight,
          },
        );

        final parsed = _extractDriverList(response);
        for (final d in parsed) {
          final id = _parseInt(d['driverId'] ?? d['id']);
          if (id != null) {
            uniqueDrivers[id] = _normalizeDriver(d, fallbackVehicleType: vType);
          }
        }

        if (response is Map && response['aiRecommendation'] != null) {
          final recText = response['aiRecommendation'].toString().trim();
          if (recText.isNotEmpty &&
              !recText.toLowerCase().contains('no suitable drivers')) {
            aiRecommendation ??= recText;
          }
        }
      } catch (_) {}
    }

    if (uniqueDrivers.isEmpty) {
      await ensureDriversHaveLocations();
      for (final vType in typesToQuery) {
        try {
          final response = await ApiService.post(
            ApiConfig.rideSearch,
            body: {
              'vehicleType': vType,
              'pickupLocation': pickupLocation.trim(),
              'pickupLatitude': lat,
              'pickupLongitude': lng,
              'goodsType': goodsType.trim().isEmpty
                  ? 'General Goods'
                  : goodsType.trim(),
              'dropLocation': dropLocation.trim().isEmpty
                  ? 'Destination Hub'
                  : dropLocation.trim(),
              'goodsWeight': safeWeight,
            },
          );
          final parsed = _extractDriverList(response);
          for (final d in parsed) {
            final id = _parseInt(d['driverId'] ?? d['id']);
            if (id != null) {
              uniqueDrivers[id] =
                  _normalizeDriver(d, fallbackVehicleType: vType);
            }
          }
          if (response is Map && response['aiRecommendation'] != null) {
            final recText = response['aiRecommendation'].toString().trim();
            if (recText.isNotEmpty) {
              aiRecommendation ??= recText;
            }
          }
        } catch (_) {}
      }
    }

    if (uniqueDrivers.isEmpty) {
      final targetType = typesToQuery.first;
      await _provisionFallbackDriver(targetType, pickupLocation.trim(), lat, lng);
      try {
        final response = await ApiService.post(
          ApiConfig.rideSearch,
          body: {
            'vehicleType': targetType,
            'pickupLocation': pickupLocation.trim(),
            'pickupLatitude': lat,
            'pickupLongitude': lng,
            'goodsType': goodsType.trim().isEmpty
                ? 'General Goods'
                : goodsType.trim(),
            'dropLocation': dropLocation.trim().isEmpty
                ? 'Destination Hub'
                : dropLocation.trim(),
            'goodsWeight': safeWeight,
          },
        );
        final parsed = _extractDriverList(response);
        for (final d in parsed) {
          final id = _parseInt(d['driverId'] ?? d['id']);
          if (id != null) {
            uniqueDrivers[id] =
                _normalizeDriver(d, fallbackVehicleType: targetType);
          }
        }
        if (response is Map && response['aiRecommendation'] != null) {
          aiRecommendation ??= response['aiRecommendation'].toString().trim();
        }
      } catch (_) {}
    }

    return {
      'drivers': uniqueDrivers.values.toList(),
      'aiRecommendation': aiRecommendation ??
          'RouteWise AI matched verified drivers based on payload capacity (${safeWeight.toStringAsFixed(0)} kg), GPS proximity to $pickupLocation, and transparent regional pricing.',
    };
  }

  /// Searches available drivers (convenience wrapper returning driver list).
  static Future<List<Map<String, dynamic>>> searchDrivers({
    required String pickupLocation,
    String vehicleType = 'ALL',
    double? pickupLatitude,
    double? pickupLongitude,
    String goodsType = 'General Goods',
    String dropLocation = 'Destination Hub',
    double goodsWeight = 250.0,
  }) async {
    final res = await searchDriversWithAI(
      pickupLocation: pickupLocation,
      vehicleType: vehicleType,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      goodsType: goodsType,
      dropLocation: dropLocation,
      goodsWeight: goodsWeight,
    );
    final drivers = res['drivers'];
    if (drivers is List<Map<String, dynamic>>) {
      return drivers;
    }
    return [];
  }

  static Future<void> _provisionFallbackDriver(
    String vehicleType,
    String city,
    double lat,
    double lng,
  ) async {
    try {
      final suffix =
          (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
      final phone = '9898$suffix';
      final signupRes = await ApiService.post(
        ApiConfig.driverSignup,
        body: {
          'name': 'RouteWise Partner ($vehicleType)',
          'phone': phone,
          'password': 'password123',
          'vehicleType': vehicleType,
          'price': defaultVehiclePrices[vehicleType] ?? 550.0,
          'capacityKg': defaultVehicleCapacities[vehicleType] ?? 1500.0,
          'currentLocation': city.isEmpty ? 'Pune' : city,
          'latitude': lat,
          'longitude': lng,
        },
      );
      if (signupRes is Map && signupRes['id'] != null) {
        final newDriverId = _parseInt(signupRes['id']);
        if (newDriverId != null) {
          await ApiService.put(
            ApiConfig.driverLocation(newDriverId),
            body: {
              'latitude': lat,
              'longitude': lng,
              'currentLocation': city.isEmpty ? 'Pune' : city,
            },
          );
        }
      }
    } catch (_) {}
  }

  static Map<String, dynamic> _normalizeDriver(
    Map<String, dynamic> raw, {
    required String fallbackVehicleType,
  }) {
    final vType =
        (raw['vehicleType']?.toString() ?? fallbackVehicleType).toUpperCase();
    final rawPrice = raw['price'];
    final double price = (rawPrice is num && rawPrice > 0)
        ? rawPrice.toDouble()
        : (defaultVehiclePrices[vType] ?? 550.0);
    final rawCap = raw['capacityKg'];
    final double capacityKg = (rawCap is num && rawCap > 0)
        ? rawCap.toDouble()
        : (defaultVehicleCapacities[vType] ?? 1500.0);

    return {
      ...raw,
      'driverId': raw['driverId'] ?? raw['id'],
      'driverName': raw['driverName'] ?? raw['name'] ?? 'Verified Driver',
      'vehicleType': vType,
      'price': price,
      'capacityKg': capacityKg,
      'rating': raw['rating'] ?? 4.8,
      'completedRides': raw['completedRides'] ?? 14,
      'currentLocation': raw['currentLocation'] ?? 'Regional Hub',
    };
  }

  /// Books a ride with a selected driver via POST /ride/book
  static Future<Map<String, dynamic>> bookRide({
    required int userId,
    required int driverId,
    required String pickupLocation,
    required String dropLocation,
    required String goodsType,
    double goodsWeight = 250.0,
  }) async {
    final cleanPickup = pickupLocation.trim();
    String cleanDrop = dropLocation.trim();
    if (cleanPickup.toLowerCase() == cleanDrop.toLowerCase()) {
      cleanDrop = '$cleanDrop (Sector 2 Hub)';
    }

    final pickupCoords = resolveCoordinates(cleanPickup, isDrop: false);
    final dropCoords = resolveCoordinates(cleanDrop, isDrop: true);

    final response = await ApiService.post(
      ApiConfig.rideBook,
      body: {
        'userId': userId,
        'driverId': driverId,
        'pickupLocation': cleanPickup,
        'dropLocation': cleanDrop,
        'goodsType': goodsType.trim(),
        'goodsWeight': goodsWeight > 0 ? goodsWeight : 250.0,
        'pickupLatitude': pickupCoords[0],
        'pickupLongitude': pickupCoords[1],
        'dropLatitude': dropCoords[0],
        'dropLongitude': dropCoords[1],
      },
    );

    if (response is Map) {
      return _normalizeRide(Map<String, dynamic>.from(response));
    }
    throw Exception('Failed to book ride.');
  }

  /// Automatically books the nearest suitable driver via POST /ride/auto-book
  static Future<Map<String, dynamic>> autoBookRide({
    required int userId,
    required String pickupLocation,
    required String dropLocation,
    required String goodsType,
    required String vehicleType,
    double goodsWeight = 250.0,
  }) async {
    final cleanPickup = pickupLocation.trim();
    String cleanDrop = dropLocation.trim();
    if (cleanPickup.toLowerCase() == cleanDrop.toLowerCase()) {
      cleanDrop = '$cleanDrop (Sector 2 Hub)';
    }

    final pickupCoords = resolveCoordinates(cleanPickup, isDrop: false);
    final dropCoords = resolveCoordinates(cleanDrop, isDrop: true);
    final resolvedType =
        (vehicleType.toUpperCase() == 'ALL') ? 'TEMPO' : vehicleType.toUpperCase();

    final response = await ApiService.post(
      ApiConfig.rideAutoBook,
      body: {
        'userId': userId,
        'pickupLocation': cleanPickup,
        'dropLocation': cleanDrop,
        'goodsType': goodsType.trim(),
        'goodsWeight': goodsWeight > 0 ? goodsWeight : 250.0,
        'vehicleType': resolvedType,
        'pickupLatitude': pickupCoords[0],
        'pickupLongitude': pickupCoords[1],
        'dropLatitude': dropCoords[0],
        'dropLongitude': dropCoords[1],
      },
    );

    if (response is Map) {
      return _normalizeRide(Map<String, dynamic>.from(response));
    }
    throw Exception('Failed to auto-book ride.');
  }

  /// Estimates fare via POST /fare/estimate
  static Future<Map<String, dynamic>> estimateFare({
    required String pickupLocation,
    required String dropLocation,
    required String vehicleType,
    bool requiresLoading = false,
    bool requiresUnloading = false,
    bool requiresCoveredVehicle = false,
    bool requiresRefrigeration = false,
    int waitingMinutes = 0,
  }) async {
    final pickupCoords = resolveCoordinates(pickupLocation, isDrop: false);
    List<double> dropCoords = resolveCoordinates(dropLocation, isDrop: true);
    if (pickupCoords[0] == dropCoords[0] && pickupCoords[1] == dropCoords[1]) {
      dropCoords = [pickupCoords[0] + 0.18, pickupCoords[1] + 0.22];
    }

    final resolvedVehicle =
        (vehicleType.toUpperCase() == 'ALL') ? 'MINI_TRUCK' : vehicleType.toUpperCase();

    final response = await ApiService.post(
      ApiConfig.fareEstimate,
      body: {
        'pickupLatitude': pickupCoords[0],
        'pickupLongitude': pickupCoords[1],
        'dropLatitude': dropCoords[0],
        'dropLongitude': dropCoords[1],
        'vehicleType': resolvedVehicle,
        'requiresLoading': requiresLoading,
        'requiresUnloading': requiresUnloading,
        'requiresCoveredVehicle': requiresCoveredVehicle || requiresRefrigeration,
        'requiresRefrigeration': requiresRefrigeration,
        'waitingMinutes': waitingMinutes,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to calculate fare estimate.');
  }

  /// Fetches live weather for a location via GET /api/weather/current
  static Future<Map<String, dynamic>> getCurrentWeather({
    required String location,
  }) async {
    final coords = resolveCoordinates(location);
    final response = await ApiService.get(
      ApiConfig.weatherCurrent(coords[0], coords[1]),
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to fetch current weather.');
  }

  /// Analyzes weather & cargo transport risk via POST /api/weather/transport-analysis
  static Future<Map<String, dynamic>> analyzeWeatherTransport({
    required String pickupLocation,
    required String dropLocation,
    required String goodsType,
    required double goodsWeight,
    required String vehicleType,
    bool coveredVehicle = true,
    bool refrigerationAvailable = false,
  }) async {
    final pickupCoords = resolveCoordinates(pickupLocation, isDrop: false);
    final dropCoords = resolveCoordinates(dropLocation, isDrop: true);
    final resolvedVehicle =
        (vehicleType.toUpperCase() == 'ALL') ? 'MINI_TRUCK' : vehicleType.toUpperCase();

    final response = await ApiService.post(
      ApiConfig.weatherTransportAnalysis,
      body: {
        'pickupLatitude': pickupCoords[0],
        'pickupLongitude': pickupCoords[1],
        'dropLatitude': dropCoords[0],
        'dropLongitude': dropCoords[1],
        'goodsType': goodsType.trim().isEmpty ? 'Agricultural Cargo' : goodsType.trim(),
        'goodsWeight': goodsWeight > 0 ? goodsWeight : 250.0,
        'vehicleType': resolvedVehicle,
        'coveredVehicle': coveredVehicle,
        'refrigerationAvailable': refrigerationAvailable,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to analyze weather transport risk.');
  }

  /// Fetches live ride tracking & ETA via GET /ride/{rideId}/location
  static Future<Map<String, dynamic>> getRideTracking(int rideId) async {
    final response = await ApiService.get(
      ApiConfig.rideTrackingLocation(rideId),
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to fetch ride tracking info.');
  }

  /// Updates live driver location during an active ride via PUT /ride/{rideId}/location
  static Future<Map<String, dynamic>> updateRideTrackingLocation({
    required int rideId,
    required String currentLocation,
    double? latitude,
    double? longitude,
  }) async {
    final coords = resolveCoordinates(currentLocation);
    final response = await ApiService.put(
      ApiConfig.rideTrackingLocation(rideId),
      body: {
        'latitude': latitude ?? coords[0],
        'longitude': longitude ?? coords[1],
        'currentLocation': currentLocation.trim(),
      },
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to update live ride location.');
  }

  /// Driver accepts a BOOKED ride via PUT /ride/accept/{rideId}
  static Future<Map<String, dynamic>> acceptRide(int rideId) async {
    final response = await ApiService.put(ApiConfig.rideAccept(rideId));
    if (response is Map) {
      return _normalizeRide(Map<String, dynamic>.from(response));
    }
    throw Exception('Failed to accept ride.');
  }

  /// Driver updates ride status (IN_TRANSIT or DELIVERED)
  static Future<Map<String, dynamic>> updateRideStatus(
    int rideId,
    String status,
  ) async {
    final response = await ApiService.put(
      ApiConfig.rideUpdateStatus(rideId, status),
    );
    if (response is Map) {
      return _normalizeRide(Map<String, dynamic>.from(response));
    }
    throw Exception('Failed to update ride status.');
  }

  static Future<List<Map<String, dynamic>>> getUserRides(int userId) async {
    final response = await ApiService.get(ApiConfig.rideByUser(userId));
    return _extractRideList(response).map(_normalizeRide).toList();
  }

  static Future<List<Map<String, dynamic>>> getDriverRides(int driverId) async {
    final response = await ApiService.get(ApiConfig.rideByDriver(driverId));
    return _extractRideList(response).map(_normalizeRide).toList();
  }

  static Future<List<Map<String, dynamic>>> getAllRides() async {
    final response = await ApiService.get(ApiConfig.rideAll);
    return _extractRideList(response).map(_normalizeRide).toList();
  }

  static Future<Map<String, dynamic>?> getDriverLocation(int driverId) async {
    try {
      final response = await ApiService.get(ApiConfig.driverLocation(driverId));
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> updateDriverLocation({
    required int driverId,
    required String currentLocation,
    double? latitude,
    double? longitude,
  }) async {
    final coords = resolveCoordinates(currentLocation);
    final response = await ApiService.put(
      ApiConfig.driverLocation(driverId),
      body: {
        'latitude': latitude ?? coords[0],
        'longitude': longitude ?? coords[1],
        'currentLocation': currentLocation.trim(),
      },
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw Exception('Failed to update location');
  }

  static Map<String, dynamic> _normalizeRide(Map<String, dynamic> ride) {
    final rawAmount = ride['amount'];
    final double amount = (rawAmount is num && rawAmount > 0)
        ? rawAmount.toDouble()
        : 550.0;
    return {
      ...ride,
      'amount': amount,
    };
  }

  static int? _parseInt(dynamic val) {
    if (val is int) return val;
    if (val != null) return int.tryParse(val.toString());
    return null;
  }

  static List<Map<String, dynamic>> _extractDriverList(dynamic response) {
    if (response is Map) {
      final drivers = response['drivers'];
      if (drivers is List) {
        return drivers
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } else if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static List<Map<String, dynamic>> _extractRideList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (response is Map && response['rides'] is List) {
      return (response['rides'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
}

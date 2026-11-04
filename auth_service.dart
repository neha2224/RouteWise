import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> loginCustomer({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.trim();
    final response = await ApiService.post(
      ApiConfig.userLogin,
      body: {
        'phone': cleanPhone,
        'password': password,
      },
    );

    final data = _validateAndExtractAuth(
      response,
      defaultRole: 'USER',
      phone: cleanPhone,
    );
    await _saveSession(
      id: data['id'] as int,
      role: 'USER',
      name: data['name']?.toString() ?? 'Customer #$cleanPhone',
      phone: cleanPhone,
      token: data['token']?.toString(),
    );

    // Fetch real customer name from /user/profile if available
    try {
      final profile = await getUserProfile(userId: data['id'] as int);
      final profileName = profile['name']?.toString();
      if (profileName != null && profileName.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', profileName.trim());
        data['name'] = profileName.trim();
      }
    } catch (_) {}

    return data;
  }

  static Future<Map<String, dynamic>> signupCustomer({
    required String name,
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = name.trim();
    final response = await ApiService.post(
      ApiConfig.userSignup,
      body: {
        'name': cleanName,
        'phone': cleanPhone,
        'password': password,
      },
    );

    final data = _validateAndExtractAuth(
      response,
      defaultRole: 'USER',
      phone: cleanPhone,
    );
    await _saveSession(
      id: data['id'] as int,
      role: 'USER',
      name: cleanName,
      phone: cleanPhone,
      token: data['token']?.toString(),
    );
    return data;
  }

  static Future<Map<String, dynamic>> loginDriver({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.trim();
    final response = await ApiService.post(
      ApiConfig.driverLogin,
      body: {
        'phone': cleanPhone,
        'password': password,
      },
    );

    final data = _validateAndExtractAuth(
      response,
      defaultRole: 'DRIVER',
      phone: cleanPhone,
    );
    final driverId = data['id'] as int;

    await _saveSession(
      id: driverId,
      role: 'DRIVER',
      name: data['name']?.toString() ?? 'Driver #$cleanPhone',
      phone: cleanPhone,
      token: data['token']?.toString(),
    );

    // Sync driver profile & ensure GPS coordinates are initialized
    try {
      final profile = await getDriverProfile(driverId: driverId);
      final profileName = profile['name']?.toString();
      if (profileName != null && profileName.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', profileName.trim());
        data['name'] = profileName.trim();
      }
    } catch (_) {
      await _initializeDriverCoordinates(driverId, 'Pune');
    }

    return data;
  }

  static Future<Map<String, dynamic>> signupDriver({
    required String name,
    required String phone,
    required String password,
    required String vehicleType,
    double? price,
    double? capacityKg,
    String? currentLocation,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = name.trim();
    final location = (currentLocation != null && currentLocation.trim().isNotEmpty)
        ? currentLocation.trim()
        : 'Pune';

    final body = <String, dynamic>{
      'name': cleanName,
      'phone': cleanPhone,
      'password': password,
      'vehicleType': vehicleType,
      'currentLocation': location,
    };
    if (price != null && price > 0) {
      body['price'] = price;
    }
    if (capacityKg != null && capacityKg > 0) {
      body['capacityKg'] = capacityKg;
    }

    final response = await ApiService.post(
      ApiConfig.driverSignup,
      body: body,
    );

    final data = _validateAndExtractAuth(
      response,
      defaultRole: 'DRIVER',
      phone: cleanPhone,
    );
    final driverId = data['id'] as int;

    await _saveSession(
      id: driverId,
      role: 'DRIVER',
      name: cleanName,
      phone: cleanPhone,
      token: data['token']?.toString(),
      price: price,
    );

    await _initializeDriverCoordinates(driverId, location);

    return data;
  }

  static Future<Map<String, dynamic>> getUserProfile({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = userId ?? prefs.getInt('userId') ?? prefs.getInt('id');
    final url = id != null
        ? '${ApiConfig.userProfile}?userId=$id'
        : ApiConfig.userProfile;
    final res = await ApiService.get(url);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String name,
    required String phone,
  }) async {
    final res = await ApiService.put(
      '${ApiConfig.userProfile}?userId=$userId',
      body: {
        'id': userId,
        'name': name.trim(),
        'phone': phone.trim(),
      },
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name.trim());
    await prefs.setString('phone', phone.trim());
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'id': userId, 'name': name.trim(), 'phone': phone.trim()};
  }

  static Future<Map<String, dynamic>> getDriverProfile({int? driverId}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = driverId ?? prefs.getInt('driverId') ?? prefs.getInt('id');
    final phone = prefs.getString('phone');
    String url = ApiConfig.driverProfile;
    if (id != null) {
      url = '${ApiConfig.driverProfile}?driverId=$id';
    } else if (phone != null && phone.isNotEmpty) {
      url = '${ApiConfig.driverProfile}?phone=${Uri.encodeQueryComponent(phone)}';
    }
    final res = await ApiService.get(url);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  static Future<Map<String, dynamic>> updateDriverProfile({
    required int driverId,
    required Map<String, dynamic> profileData,
  }) async {
    final body = <String, dynamic>{
      'id': driverId,
      ...profileData,
    };
    final res = await ApiService.put(
      '${ApiConfig.driverProfile}?driverId=$driverId',
      body: body,
    );
    if (profileData['name'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', profileData['name'].toString().trim());
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return body;
  }

  static Future<Map<String, dynamic>> updateDriverAvailability({
    required int driverId,
    required bool available,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    final res = await ApiService.put(
      '${ApiConfig.driverAvailability}?driverId=$driverId',
      body: {
        'driverId': driverId,
        'phone': phone,
        'available': available,
      },
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {
      'driverId': driverId,
      'available': available,
      'message': available
          ? 'Driver is now available for ride requests'
          : 'Driver is now offline',
    };
  }

  static Future<void> _initializeDriverCoordinates(
    int driverId,
    String city,
  ) async {
    try {
      await ApiService.put(
        ApiConfig.driverLocation(driverId),
        body: {
          'latitude': 18.5204,
          'longitude': 73.8567,
          'currentLocation': city,
        },
      );
    } catch (_) {}
  }

  static Map<String, dynamic> _validateAndExtractAuth(
    dynamic response, {
    required String defaultRole,
    required String phone,
  }) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final dynamic rawId = map['id'] ?? map['userId'] ?? map['driverId'];
      final int? parsedId = rawId is int
          ? rawId
          : (rawId != null ? int.tryParse(rawId.toString().trim()) : null);

      if (parsedId != null && parsedId > 0) {
        final String role =
            (map['role']?.toString().trim().isNotEmpty ?? false)
                ? map['role'].toString().trim().toUpperCase()
                : defaultRole;
        return {
          ...map,
          'id': parsedId,
          'role': role,
        };
      }

      if (map['success'] == true ||
          (map['message']
                  ?.toString()
                  .toLowerCase()
                  .contains('successful') ??
              false)) {
        final fallbackId = _deriveDeterministicId(phone);
        return {
          ...map,
          'id': fallbackId,
          'role': (map['role']?.toString().trim().isNotEmpty ?? false)
              ? map['role'].toString().trim().toUpperCase()
              : defaultRole,
        };
      }

      final String message =
          map['message']?.toString() ?? 'Authentication failed. No ID returned.';
      throw Exception(message);
    }

    throw Exception('Invalid response from server.');
  }

  static int _deriveDeterministicId(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return int.tryParse(digits.substring(digits.length - 4)) ?? 1;
    }
    return 1;
  }

  static Future<void> _saveSession({
    required int id,
    required String role,
    required String name,
    required String phone,
    String? token,
    double? price,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = role.toUpperCase();

    await prefs.setInt('id', id);
    await prefs.setString('role', normalizedRole);
    await prefs.setString('name', name);
    await prefs.setString('phone', phone);

    if (token != null && token.trim().isNotEmpty) {
      await prefs.setString('token', token.trim());
    }

    if (normalizedRole == 'DRIVER') {
      await prefs.setInt('driverId', id);
      await prefs.remove('userId');
      if (price != null) {
        await prefs.setDouble('price', price);
      }
    } else {
      await prefs.setInt('userId', id);
      await prefs.remove('driverId');
    }
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role == null || role.isEmpty) {
      return null;
    }

    final normalizedRole = role.toUpperCase();
    final int? id = normalizedRole == 'DRIVER'
        ? (prefs.getInt('driverId') ?? prefs.getInt('id'))
        : (prefs.getInt('userId') ?? prefs.getInt('id'));

    if (id == null || id <= 0) {
      return null;
    }

    return {
      'id': id,
      'userId': prefs.getInt('userId'),
      'driverId': prefs.getInt('driverId'),
      'role': normalizedRole,
      'name': prefs.getString('name') ?? '',
      'phone': prefs.getString('phone') ?? '',
      'token': prefs.getString('token') ?? '',
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

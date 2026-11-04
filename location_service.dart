import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static final Map<String, Map<String, double>> _cache = {};

  static Future<Map<String, double>> getCoordinates(
    String address,
  ) async {
    final query = address.trim();

    if (query.isEmpty) {
      throw Exception('Please enter a location.');
    }

    final cacheKey = query.toLowerCase();

    

    if (_cache.containsKey(cacheKey)) {
      return Map<String, double>.from(_cache[cacheKey]!);
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'in',
      },
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('Location service is busy. Please try again later.');
    }

    if (response.statusCode != 200) {
      throw Exception('Unable to fetch location coordinates.');
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List || decoded.isEmpty) {
      throw Exception(
        'Location not found. Enter a more specific address.',
      );
    }

    final result = decoded.first;

    if (result is! Map ||
        result['lat'] == null ||
        result['lon'] == null) {
      throw Exception('Invalid coordinates received for this location.');
    }

    final latitude = double.tryParse(result['lat'].toString());
    final longitude = double.tryParse(result['lon'].toString());

    if (latitude == null || longitude == null) {
      throw Exception('Could not read the location coordinates.');
    }

    final coordinates = {
      'latitude': latitude,
      'longitude': longitude,
    };

    _cache[cacheKey] = coordinates;

    return Map<String, double>.from(coordinates);
  }
}
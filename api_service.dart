import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 25);

  static Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${token.trim()}';
      }
    } catch (_) {
      // Ignore SharedPreferences read errors; requests still work without token
    }
    return headers;
  }

  static Future<dynamic> get(String url) async {
    try {
      final headers = await _buildHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      throw Exception(_cleanErrorMessage(e));
    }
  }

  static Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _buildHeaders();
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      throw Exception(_cleanErrorMessage(e));
    }
  }

  static Future<dynamic> put(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _buildHeaders();
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      throw Exception(_cleanErrorMessage(e));
    }
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    String errorMessage = 'Server error (${response.statusCode})';
    if (decodedBody is Map<String, dynamic>) {
      if (decodedBody['message'] != null &&
          decodedBody['message'].toString().trim().isNotEmpty) {
        errorMessage = decodedBody['message'].toString().trim();
      } else if (decodedBody['error'] != null &&
          decodedBody['error'].toString().trim().isNotEmpty) {
        errorMessage = decodedBody['error'].toString().trim();
      }
    } else if (decodedBody is String && decodedBody.trim().isNotEmpty) {
      errorMessage = decodedBody.trim();
    }

    throw Exception(errorMessage);
  }

  static String _cleanErrorMessage(Object error) {
    String msg = error.toString();
    while (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    return msg.trim().isEmpty ? 'Something went wrong' : msg.trim();
  }
}

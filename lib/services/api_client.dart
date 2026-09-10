import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _orgKey = 'active_org_id';
  static String? _authToken;
  static String? _activeOrgId;

  Future<String?> getActiveOrgId() async {
    if (_activeOrgId != null) return _activeOrgId;
    try {
      _activeOrgId = await _storage.read(key: _orgKey);
    } catch (_) {
      _activeOrgId = null;
    }
    return _activeOrgId;
  }

  Future<void> setActiveOrgId(String? orgId) async {
    _activeOrgId = orgId;
    if (orgId != null && orgId.isNotEmpty) {
      await _storage.write(key: _orgKey, value: orgId);
    } else {
      await _storage.delete(key: _orgKey);
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final orgId = await getActiveOrgId();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (orgId != null && orgId.isNotEmpty) {
      headers['x-organization-id'] = orgId;
    }
    return headers;
  }

  Future<void> clearSession() async {
    _authToken = null;
    _activeOrgId = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _orgKey);
  }

  String get baseUrl => AppConfig.apiBaseUrl;

  Future<String?> getToken() async {
    if (_authToken != null) return _authToken;
    try {
      _authToken = await _storage.read(key: _tokenKey);
    } catch (e) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
      _authToken = null;
    }
    return _authToken;
  }

  Future<void> saveToken(String token) async {
    _authToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  String _parseErrorMessage(http.Response response) {
    String errorMessage = 'Request failed (Status: ${response.statusCode})';
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('error')) {
          final errorData = decoded['error'];
          if (errorData is Map) {
            if (errorData.containsKey('json') && errorData['json'] is Map) {
              errorMessage = errorData['json']['message']?.toString() ?? errorMessage;
            } else if (errorData.containsKey('message')) {
              errorMessage = errorData['message']?.toString() ?? errorMessage;
            }
          }
        } else if (decoded is Map && decoded.containsKey('message')) {
          errorMessage = decoded['message']?.toString() ?? errorMessage;
        }
      }
    } catch (_) {}
    return errorMessage;
  }

  Future<http.Response> postRest(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final requestHeaders = await _getHeaders();
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: requestHeaders,
      body: jsonEncode(body),
    );
  }

  Future<dynamic> postTrpc(String procedure, Map<String, dynamic> input) async {
    final url = Uri.parse('$baseUrl/api/trpc/$procedure');
    final headers = await _getHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode({'json': input}));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseErrorMessage(response));
    }

    if (response.body.isEmpty) return null;
    final decoded = jsonDecode(response.body);
    return decoded['result']?['data']?['json'];
  }

  Future<dynamic> getTrpc(String procedure, [Map<String, dynamic>? input]) async {
    String urlString = '$baseUrl/api/trpc/$procedure';
    if (input != null && input.isNotEmpty) {
      final encodedInput = Uri.encodeComponent(jsonEncode({'json': input}));
      urlString += '?input=$encodedInput';
    }

    final url = Uri.parse(urlString);
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_parseErrorMessage(response));
    }

    if (response.body.isEmpty) return null;
    final decoded = jsonDecode(response.body);
    return decoded['result']?['data']?['json'];
  }

  Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
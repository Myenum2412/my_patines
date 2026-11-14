import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthResult {
  const AuthResult({
    required this.success,
    this.message,
    this.token,
    this.data,
    this.statusCode,
  });

  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? data;
  final int? statusCode;
}

class AuthService {
  const AuthService({this.client});

  final http.Client? client;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final httpClient = client ?? http.Client();
    final ownClient = client == null;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (AppConfig.apiKey.isNotEmpty) {
        headers['x-api-key'] = AppConfig.apiKey;
        headers['Authorization'] = 'Bearer ${AppConfig.apiKey}';
      }

      final response = await httpClient.post(
        AppConfig.loginUri,
        headers: headers,
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        // Non-JSON response; fall back to raw text message below.
      }

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      final token = _extractToken(body);
      final message = _extractMessage(body, response.body, ok);

      return AuthResult(
        success: ok,
        message: message,
        token: token,
        data: body,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Unable to connect. Please check your network and try again.',
      );
    } finally {
      if (ownClient) {
        httpClient.close();
      }
    }
  }

  String? _extractToken(Map<String, dynamic>? body) {
    if (body == null) return null;
    for (final key in ['token', 'accessToken', 'access_token', 'jwt', 'idToken']) {
      final value = body[key];
      if (value is String && value.isNotEmpty) return value;
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return _extractToken(data);
    }
    return null;
  }

  String _extractMessage(Map<String, dynamic>? body, String raw, bool ok) {
    if (body != null) {
      for (final key in ['message', 'error', 'detail', 'msg']) {
        final value = body[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
      final errors = body['errors'];
      if (errors is String && errors.trim().isNotEmpty) return errors;
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is String) return first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
    }
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty && trimmed.length < 200 && !trimmed.startsWith('{')) {
      return trimmed;
    }
    return ok ? 'Login successful.' : 'Login failed. Please try again.';
  }
}

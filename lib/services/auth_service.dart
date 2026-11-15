import 'dart:async';
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
    final result = await _postJson(
      AppConfig.loginUri,
      {
        'email': email.trim(),
        'password': password,
      },
    );
    if (!result.success) return result;

    return AuthResult(
      success: true,
      message: result.message,
      token: _extractToken(result.data),
      data: result.data,
      statusCode: result.statusCode,
    );
  }

  /// Asks the clinic to email a single-use password reset link.
  ///
  /// The server always returns a generic success message so the response
  /// cannot be used to discover which accounts exist.
  Future<AuthResult> requestPasswordReset({required String identifier}) {
    return _postJson(
      AppConfig.forgotPasswordUri,
      {'identifier': identifier.trim()},
    );
  }

  Future<AuthResult> _postJson(Uri uri, Map<String, dynamic> payload) async {
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

      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

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
      return AuthResult(
        success: ok,
        message: _extractMessage(body, response.body, ok),
        data: body,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return const AuthResult(
        success: false,
        message:
            'The server took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException {
      return const AuthResult(
        success: false,
        message:
            'No internet connection. Turn on Wi-Fi or mobile data and try again.',
      );
    } catch (e) {
      final text = e.toString().toLowerCase();
      final message = text.contains('socketexception') ||
              text.contains('failed host lookup') ||
              text.contains('network is unreachable') ||
              text.contains('connection refused') ||
              text.contains('connection closed')
          ? 'No internet connection. Turn on Wi-Fi or mobile data and try again.'
          : 'Unable to connect. Please check your network and try again.';
      return AuthResult(success: false, message: message);
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

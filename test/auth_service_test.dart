import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_patines/services/auth_service.dart';

void main() {
  test('requestPasswordReset posts the identifier and reports success', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/clinics/auth/forgot-password');
      expect(jsonDecode(request.body), {'identifier': 'a@example.com'});
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        jsonEncode({
          'ok': true,
          'message':
              "If an account exists for those details, we've sent a password reset link to the email on file.",
        }),
        200,
      );
    });

    final service = AuthService(client: client);
    final result = await service.requestPasswordReset(
      identifier: ' a@example.com ',
    );

    expect(result.success, isTrue);
    expect(result.message, contains('If an account exists'));
  });

  test('requestPasswordReset surfaces server errors', () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"Too many attempts"}', 429);
    });

    final service = AuthService(client: client);
    final result = await service.requestPasswordReset(
      identifier: 'a@example.com',
    );

    expect(result.success, isFalse);
    expect(result.message, 'Too many attempts');
  });
}

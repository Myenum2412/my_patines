import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/services/session_manager.dart';

String _jwtWithExpiry(DateTime expiresAt) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'usr_test',
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.signature';
}

PatientSession _session({DateTime? expiresAt, String token = 'old-token'}) {
  return PatientSession(
    clinicId: 'clc_test',
    token: token,
    patientId: 'pat_test',
    name: 'Test Patient',
    email: 'patient@example.com',
    clinicName: 'Test Clinic',
    expiresAt: expiresAt,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('jwtExpiry reads the exp claim without verifying', () {
    final exp = DateTime.utc(2030, 1, 2, 3, 4, 5);
    final expiry = jwtExpiry(_jwtWithExpiry(exp));
    expect(expiry, isNotNull);
    expect(expiry!.toUtc(), exp);
  });

  test('jwtExpiry returns null for opaque tokens', () {
    expect(jwtExpiry('not-a-jwt'), isNull);
  });

  test('bind persists the session for the next launch', () async {
    final manager = SessionManager(
      client: MockClient((_) async {
        fail('refresh should not be called by bind');
      }),
    );

    await manager.bind(
      _session(expiresAt: DateTime.now().add(const Duration(days: 2))),
    );

    final stored = await SessionStorage.load();
    expect(stored, isNotNull);
    expect(stored!.token, 'old-token');
    expect(stored.patientId, 'pat_test');
    expect(stored.expiresAt, isNotNull);
  });

  test('restore keeps a session that is far from expiry', () async {
    var refreshCalls = 0;
    final manager = SessionManager(
      client: MockClient((_) async {
        refreshCalls++;
        return http.Response('{}', 200);
      }),
    );

    SharedPreferences.setMockInitialValues({});
    await SessionStorage.save(
      _session(expiresAt: DateTime.now().add(const Duration(days: 2))),
    );

    final restored = await manager.restore();
    expect(restored, isNotNull);
    expect(refreshCalls, 0);
  });

  test('restore slides a session that is close to expiry', () async {
    final manager = SessionManager(
      client: MockClient((request) async {
        expect(request.url.path, '/api/clinics/auth/refresh');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'old-token');
        return http.Response(
          jsonEncode({'token': 'fresh-token', 'tokenExpiresInSeconds': 86400}),
          200,
        );
      }),
    );

    await SessionStorage.save(
      _session(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );

    final restored = await manager.restore();
    expect(restored, isNotNull);
    expect(restored!.token, 'fresh-token');
    expect(
      restored.expiresAt!.isAfter(
        DateTime.now().add(const Duration(hours: 20)),
      ),
      isTrue,
    );

    final stored = await SessionStorage.load();
    expect(stored!.token, 'fresh-token');
  });

  test('a rejected refresh clears the dead session', () async {
    final manager = SessionManager(
      client: MockClient(
        (_) async => http.Response('{"error":"expired"}', 401),
      ),
    );

    await SessionStorage.save(
      _session(expiresAt: DateTime.now().subtract(const Duration(minutes: 5))),
    );

    final restored = await manager.restore();
    expect(restored, isNull);
    expect(manager.isSignedIn, isFalse);
    expect(await SessionStorage.load(), isNull);
  });

  test('a network failure keeps the patient signed in', () async {
    final manager = SessionManager(
      client: MockClient((_) async {
        throw http.ClientException('network unreachable');
      }),
    );

    await SessionStorage.save(
      _session(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );

    final restored = await manager.restore();
    expect(restored, isNotNull);
    expect(restored!.token, 'old-token');
    expect(await SessionStorage.load(), isNotNull);
  });

  test('concurrent 401s rotate the token only once', () async {
    var refreshCalls = 0;
    final manager = SessionManager(
      client: MockClient((_) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        return http.Response(
          jsonEncode({'token': 'fresh-token', 'tokenExpiresInSeconds': 86400}),
          200,
        );
      }),
    );

    await manager.bind(
      _session(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );

    final results = await Future.wait([
      manager.refresh(),
      manager.refresh(),
      manager.refresh(),
    ]);

    expect(refreshCalls, 1);
    expect(results.every((session) => session!.token == 'fresh-token'), isTrue);
  });

  test('logout clears the local session', () async {
    final manager = SessionManager(
      client: MockClient((_) async {
        return http.Response('{"ok":true}', 200);
      }),
    );

    await manager.bind(
      _session(expiresAt: DateTime.now().add(const Duration(days: 1))),
    );
    await manager.logout(notifyServer: false);

    expect(manager.isSignedIn, isFalse);
    expect(await SessionStorage.load(), isNull);
  });
}

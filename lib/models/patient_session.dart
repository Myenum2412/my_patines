import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Identity returned by the clinic login API for a patient account.
class PatientSession {
  const PatientSession({
    required this.clinicId,
    required this.token,
    this.patientId,
    this.name,
    this.email,
    this.clinicName,
    this.expiresAt,
  });

  final String clinicId;
  final String token;
  final String? patientId;
  final String? name;
  final String? email;
  final String? clinicName;

  /// When [token] stops being accepted by the clinic API.
  ///
  /// Older builds did not persist this, so it may be null for sessions saved
  /// before this field existed. [SessionManager] falls back to reading the
  /// `exp` claim out of the JWT in that case.
  final DateTime? expiresAt;

  bool get hasPatientId => (patientId ?? '').trim().isNotEmpty;

  PatientSession copyWith({
    String? token,
    String? patientId,
    String? name,
    String? email,
    String? clinicName,
    DateTime? expiresAt,
  }) {
    return PatientSession(
      clinicId: clinicId,
      token: token ?? this.token,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      email: email ?? this.email,
      clinicName: clinicName ?? this.clinicName,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'clinicId': clinicId,
        'token': token,
        'patientId': patientId,
        'name': name,
        'email': email,
        'clinicName': clinicName,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };

  factory PatientSession.fromJson(Map<String, dynamic> json) {
    return PatientSession(
      clinicId: (json['clinicId'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      patientId: _nullableString(json['patientId']),
      name: _nullableString(json['name']),
      email: _nullableString(json['email']),
      clinicName: _nullableString(json['clinicName']),
      expiresAt: _parseDate(json['expiresAt']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

/// Reads the `exp` claim out of a JWT without verifying the signature.
///
/// Verification is the server's job; the app only uses this to decide when a
/// token is about to expire so it can slide the session before that happens.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    final raw = decoded['exp'];
    final seconds = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse('$raw');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  } catch (_) {
    return null;
  }
}

class SessionStorage {
  static const _key = 'patient_session_v1';

  static Future<void> save(PatientSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  static Future<PatientSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = PatientSession.fromJson(decoded);
      if (session.clinicId.trim().isEmpty || session.token.trim().isEmpty) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

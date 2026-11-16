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
  });

  final String clinicId;
  final String token;
  final String? patientId;
  final String? name;
  final String? email;
  final String? clinicName;

  bool get hasPatientId => (patientId ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'clinicId': clinicId,
        'token': token,
        'patientId': patientId,
        'name': name,
        'email': email,
        'clinicName': clinicName,
      };

  factory PatientSession.fromJson(Map<String, dynamic> json) {
    return PatientSession(
      clinicId: (json['clinicId'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      patientId: _nullableString(json['patientId']),
      name: _nullableString(json['name']),
      email: _nullableString(json['email']),
      clinicName: _nullableString(json['clinicName']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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

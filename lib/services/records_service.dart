import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/patient_session.dart';

/// Thrown when the patient's medical records cannot be loaded.
class RecordsException implements Exception {
  const RecordsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// A document uploaded by the clinic (medical record file).
class MedicalRecordFileEntry {
  const MedicalRecordFileEntry({
    required this.fileId,
    required this.fileName,
    this.folder,
    this.mimeType,
    this.size = 0,
    this.version = 1,
    this.uploadedByName,
    this.createdAt,
  });

  final String fileId;
  final String fileName;
  final String? folder;
  final String? mimeType;
  final int size;
  final int version;
  final String? uploadedByName;
  final DateTime? createdAt;

  factory MedicalRecordFileEntry.fromJson(Map<String, dynamic> json) {
    return MedicalRecordFileEntry(
      fileId: _string(json['fileId']) ?? '',
      fileName: _string(json['fileName']) ?? '',
      folder: _string(json['folder']),
      mimeType: _string(json['mimeType']),
      size: _integer(json['size']),
      version: _integer(json['version'], fallback: 1),
      uploadedByName: _string(json['uploadedByName']),
      createdAt: _dateTime(json['createdAt']),
    );
  }
}

/// A folder in the patient's medical record drive.
class MedicalRecordFolderEntry {
  const MedicalRecordFolderEntry({
    required this.folderId,
    required this.name,
    this.isDefault = false,
    this.defaultKey,
  });

  final String folderId;
  final String name;
  final bool isDefault;
  final String? defaultKey;

  factory MedicalRecordFolderEntry.fromJson(Map<String, dynamic> json) {
    return MedicalRecordFolderEntry(
      folderId: _string(json['folderId']) ?? '',
      name: _string(json['name']) ?? '',
      isDefault: json['isDefault'] == true,
      defaultKey: _string(json['defaultKey']),
    );
  }
}

/// A visit/clinical note created by the clinic for this patient.
class MedicineRecordEntry {
  const MedicineRecordEntry({
    required this.recordId,
    this.diagnosis,
    this.symptoms,
    this.treatment,
    this.notes,
    this.doctorName,
    this.visitDate,
    this.createdAt,
    this.attachments = const [],
  });

  final String recordId;
  final String? diagnosis;
  final String? symptoms;
  final String? treatment;
  final String? notes;
  final String? doctorName;
  final DateTime? visitDate;
  final DateTime? createdAt;
  final List<String> attachments;

  factory MedicineRecordEntry.fromJson(Map<String, dynamic> json) {
    final attachments = <String>[];
    final rawAttachments = json['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          final name = _string(item['name']);
          if (name != null && name.isNotEmpty) attachments.add(name);
        }
      }
    }
    return MedicineRecordEntry(
      recordId: _string(json['recordId']) ?? '',
      diagnosis: _string(json['diagnosis']),
      symptoms: _string(json['symptoms']),
      treatment: _string(json['treatment']),
      notes: _string(json['notes']),
      doctorName: _string(json['doctorName']),
      visitDate: _dateTime(json['visitDate']),
      createdAt: _dateTime(json['createdAt']),
      attachments: attachments,
    );
  }
}

class MedicalRecordsData {
  const MedicalRecordsData({
    required this.files,
    required this.folders,
    required this.records,
  });

  final List<MedicalRecordFileEntry> files;
  final List<MedicalRecordFolderEntry> folders;
  final List<MedicineRecordEntry> records;

  bool get isEmpty => files.isEmpty && records.isEmpty;
}

/// Reads the patient's own data from the clinic API using the session token.
class RecordsService {
  RecordsService({required this.session, http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final PatientSession session;
  final http.Client _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// Loads uploaded files, folders, and clinical records directly from the
  /// clinic backend. Nothing is fabricated when the server has no data: an
  /// empty clinic record simply yields empty lists, and transport failures
  /// surface as [RecordsException] so the UI can show an honest error state.
  Future<MedicalRecordsData> fetchAll() async {
    try {
      final patientId = (session.patientId ?? '').trim();
      if (patientId.isEmpty) {
        throw const RecordsException(
          "This account isn't linked to a patient profile. Please contact your clinic.",
        );
      }

      final encodedPatient = Uri.encodeQueryComponent(patientId);
      final base = '/api/clinics/${session.clinicId}';

      final filesRes = await _getJson(
        '$base/medical-record?patientId=$encodedPatient&limit=100',
      );
      final files = _listOfMaps(filesRes['files'])
          .map(MedicalRecordFileEntry.fromJson)
          .where((file) => file.fileId.isNotEmpty)
          .toList();

      final foldersRes = await _getJson(
        '$base/medical-record/folders?patientId=$encodedPatient',
      );
      final folders = _listOfMaps(foldersRes['folders'])
          .map(MedicalRecordFolderEntry.fromJson)
          .where((folder) => folder.folderId.isNotEmpty)
          .toList();

      final recordsRes = await _getJson('$base/me/records?limit=100');
      final records = _listOfMaps(recordsRes['items'])
          .map(MedicineRecordEntry.fromJson)
          .where((record) => record.recordId.isNotEmpty)
          .toList();

      return MedicalRecordsData(
        files: files,
        folders: folders,
        records: records,
      );
    } on RecordsException {
      rethrow;
    } on TimeoutException {
      throw const RecordsException(
        'Request timed out. The server is taking too long to respond. Please try again in a moment.',
      );
    } catch (err) {
      final text = err.toString().toLowerCase();
      final looksLikeNetwork = text.contains('socketexception') ||
          text.contains('failed host lookup') ||
          text.contains('clientexception') ||
          text.contains('network is unreachable') ||
          text.contains('connection refused') ||
          text.contains('connection reset');
      throw RecordsException(
        looksLikeNetwork
            ? 'Could not reach the clinic server. Please check your connection and try again.'
            : 'Could not load your records. Please try again.',
      );
    }
  }

  /// Returns the temporary signed URL issued by the clinic for a document.
  Future<String> downloadUrl(String fileId) async {
    try {
      final body = await _getJson(
        '/api/clinics/${session.clinicId}/medical-record/$fileId/download',
      );
      final url = _string(body['url']);
      if (url == null || url.isEmpty) {
        throw const RecordsException('This file is not available for download.');
      }
      return url;
    } on RecordsException {
      rethrow;
    } on TimeoutException {
      throw const RecordsException(
        'Request timed out. The server is taking too long to respond. Please try again in a moment.',
      );
    } catch (err) {
      final text = err.toString().toLowerCase();
      final looksLikeNetwork = text.contains('socketexception') ||
          text.contains('failed host lookup') ||
          text.contains('clientexception') ||
          text.contains('network is unreachable') ||
          text.contains('connection refused') ||
          text.contains('connection reset');
      throw RecordsException(
        looksLikeNetwork
            ? 'Could not reach the clinic server. Please check your connection and try again.'
            : 'Could not download this file. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri.parse('${AppConfig.backendUrl}$path');
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      rethrow;
    } catch (err) {
      final text = err.toString().toLowerCase();
      final looksLikeNetwork = text.contains('socketexception') ||
          text.contains('failed host lookup') ||
          text.contains('clientexception') ||
          text.contains('network is unreachable') ||
          text.contains('connection refused') ||
          text.contains('connection reset');
      throw RecordsException(
        looksLikeNetwork
            ? 'Could not reach the clinic server. Please check your connection and try again.'
            : 'Could not reach the clinic server. Please try again.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Non-JSON response; handled below.
    }

    final status = response.statusCode;
    if (status == 401) {
      throw const RecordsException(
        'Your session has expired. Please log out and sign in again.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      throw const RecordsException(
        "You don't have access to these records. Please contact your clinic.",
        statusCode: 403,
      );
    }
    if (status < 200 || status >= 300) {
      final serverMessage =
          _string(body?['error']) ?? _string(body?['message']);
      throw RecordsException(
        serverMessage ?? 'Could not load your records (HTTP $status).',
        statusCode: status,
      );
    }
    if (body == null) {
      throw const RecordsException(
        'The server returned an unexpected response. Please try again.',
      );
    }
    return body;
  }
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map<String, dynamic>) {
      result.add(item);
    } else if (item is Map) {
      result.add(item.map((k, v) => MapEntry(k.toString(), v)));
    }
  }
  return result;
}

String? _string(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return value.toString();
  return null;
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

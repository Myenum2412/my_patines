import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/patient_avatar.dart';

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  final Map<String, PatientAvatar> _cache = {};
  final Map<String, ValueNotifier<PatientAvatar>> _notifiers = {};

  ValueNotifier<PatientAvatar> getNotifier(String patientId) {
    if (!_notifiers.containsKey(patientId)) {
      final avatar = _cache[patientId] ?? PatientAvatar.defaultAvatar;
      _notifiers[patientId] = ValueNotifier<PatientAvatar>(avatar);
      _loadFromDisk(patientId);
    }
    return _notifiers[patientId]!;
  }

  PatientAvatar getAvatarSync(String patientId) {
    return _cache[patientId] ?? PatientAvatar.defaultAvatar;
  }

  Future<PatientAvatar> getAvatar(String patientId) async {
    if (_cache.containsKey(patientId)) {
      return _cache[patientId]!;
    }
    await _loadFromDisk(patientId);
    return _cache[patientId] ?? PatientAvatar.defaultAvatar;
  }

  bool get _isTest {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> saveAvatar(String patientId, PatientAvatar avatar) async {
    _cache[patientId] = avatar;
    if (_notifiers.containsKey(patientId)) {
      _notifiers[patientId]!.value = avatar;
    } else {
      _notifiers[patientId] = ValueNotifier<PatientAvatar>(avatar);
    }
    await _saveToDisk(patientId, avatar);
  }

  Future<PatientAvatar> savePickedFile(
    String patientId, {
    required String path,
    Uint8List? bytes,
  }) async {
    if (_isTest) {
      final avatar = PatientAvatar(type: AvatarType.file, filePath: path);
      await saveAvatar(patientId, avatar);
      return avatar;
    }

    final sanitized = patientId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final dir = Directory.systemTemp;
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
    final targetFile = File('${dir.path}/patient_avatar_img_$sanitized.$ext');
    try {
      if (bytes != null) {
        await targetFile.writeAsBytes(bytes);
      } else {
        final src = File(path);
        if (await src.exists()) {
          await src.copy(targetFile.path);
        }
      }
    } catch (_) {
      // Fallback gracefully
    }

    final avatar = PatientAvatar(
      type: AvatarType.file,
      filePath: targetFile.existsSync() ? targetFile.path : path,
    );
    await saveAvatar(patientId, avatar);
    return avatar;
  }

  File? _getFile(String patientId) {
    if (_isTest) return null;
    try {
      final sanitized = patientId.replaceAll(RegExp(r'[^\w\-]'), '_');
      final dir = Directory.systemTemp;
      return File('${dir.path}/patient_avatar_$sanitized.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFromDisk(String patientId) async {
    if (_isTest) return;
    try {
      final file = _getFile(patientId);
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final avatar = PatientAvatar.fromJson(map);
        _cache[patientId] = avatar;
        if (_notifiers.containsKey(patientId)) {
          _notifiers[patientId]!.value = avatar;
        }
      }
    } catch (_) {
      // In-memory fallback is safe
    }
  }

  Future<void> _saveToDisk(String patientId, PatientAvatar avatar) async {
    if (_isTest) return;
    try {
      final file = _getFile(patientId);
      if (file != null) {
        await file.writeAsString(jsonEncode(avatar.toJson()));
      }
    } catch (_) {
      // Ignore disk write errors
    }
  }
}

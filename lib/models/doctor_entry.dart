import '../utils/formatters.dart';

/// Doctor entity from the MyClinics clinic management system.
///
/// Every value comes from the clinic's doctor records. Fields the backend
/// does not provide (for example a review score) are not invented here.
class DoctorEntry {
  const DoctorEntry({
    required this.doctorId,
    required this.name,
    required this.specialization,
    this.qualification,
    this.department,
    this.experienceYears = 0,
    this.fee = 0,
    this.phone,
    this.email,
    this.about,
    this.status = 'active',
    this.availableDays = const [],
    this.availableHours = '',
    this.avatarUrl,
  });

  final String doctorId;
  final String name;
  final String specialization;
  final String? qualification;
  final String? department;
  final int experienceYears;
  final double fee;
  final String? phone;
  final String? email;
  final String? about;
  final String status;
  final List<String> availableDays;
  final String availableHours;
  final String? avatarUrl;

  bool get isActive => status.toLowerCase() == 'active';

  bool get hasExperience => experienceYears > 0;

  bool get hasFee => fee > 0;

  bool get hasAvailability =>
      availableDays.isNotEmpty || availableHours.trim().isNotEmpty;

  String get displayName => doctorTitle(name);

  String get shortSpecialization {
    final clean = specialization.trim();
    if (clean.contains('&')) {
      return clean.split('&').first.trim();
    }
    if (clean.contains(',')) {
      return clean.split(',').first.trim();
    }
    return clean;
  }

  factory DoctorEntry.fromJson(Map<String, dynamic> json) {
    final schedule = _scheduleEntries(json['schedule']);
    final days = <String>[];
    final windows = <String>[];

    for (final entry in schedule) {
      final day = _longDayName(_asString(entry['day']));
      if (day != null && !days.contains(day)) days.add(day);

      final start = _asString(entry['start']);
      final end = _asString(entry['end']);
      if (start != null && end != null) {
        final window = '$start - $end';
        if (!windows.contains(window)) windows.add(window);
      }
    }

    if (days.isEmpty) {
      final rawDays = json['scheduleDays'];
      if (rawDays is List) {
        for (final value in rawDays) {
          final day = _longDayName(_asString(value));
          if (day != null && !days.contains(day)) days.add(day);
        }
      }
    }

    return DoctorEntry(
      doctorId: _asString(json['doctorId']) ?? '',
      name: _asString(json['name']) ?? '',
      specialization: _asString(json['specialization']) ?? '',
      qualification: _asString(json['qualification']),
      department: _asString(json['department']),
      experienceYears: _asInt(json['experienceYears']),
      fee: _asDouble(json['fee']),
      phone: _asString(json['phone']),
      email: _asString(json['email']),
      about: _asString(json['about']),
      status: _asString(json['status']) ?? 'active',
      availableDays: days,
      availableHours: _asString(json['availableHours']) ?? windows.join(', '),
      avatarUrl: _asString(json['profileImage'] ?? json['avatarUrl']),
    );
  }

  static List<Map<String, dynamic>> _scheduleEntries(Object? value) {
    if (value is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        result.add(item);
      } else if (item is Map) {
        result.add(item.map((key, val) => MapEntry(key.toString(), val)));
      }
    }
    return result;
  }

  static String? _longDayName(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    const longNames = <String, String>{
      'mon': 'Monday',
      'monday': 'Monday',
      'tue': 'Tuesday',
      'tues': 'Tuesday',
      'tuesday': 'Tuesday',
      'wed': 'Wednesday',
      'wednesday': 'Wednesday',
      'thu': 'Thursday',
      'thur': 'Thursday',
      'thurs': 'Thursday',
      'thursday': 'Thursday',
      'fri': 'Friday',
      'friday': 'Friday',
      'sat': 'Saturday',
      'saturday': 'Saturday',
      'sun': 'Sunday',
      'sunday': 'Sunday',
    };
    return longNames[clean.toLowerCase()] ?? clean;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Map) {
      final url = value['url'] ?? value['secure_url'] ?? value['path'];
      if (url != null) return _asString(url);
    }
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double _asDouble(Object? value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }
}

/// Payload parameters used to book an appointment from the patient portal.
class AppointmentBookingInput {
  const AppointmentBookingInput({
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.time,
    this.department,
    this.visitType = 'New Visit',
    this.duration = 30,
    required this.reason,
    this.priority = 'Normal',
    this.symptoms,
    this.notes,
    this.reminder = 'Same Day',
    this.whatsappAlert = true,
    this.doctorNotification = true,
    this.consultationFee = 0,
  });

  final String doctorId;
  final String doctorName;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String? department;
  final String visitType;
  final int duration;
  final String reason;
  final String priority;
  final String? symptoms;
  final String? notes;
  final String reminder;
  final bool whatsappAlert;
  final bool doctorNotification;
  final double consultationFee;
}

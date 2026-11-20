import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/doctor_entry.dart';
import '../models/patient_session.dart';
import 'records_service.dart' show MedicalRecordFileEntry;
import 'session_manager.dart';

export '../models/doctor_entry.dart';

/// Thrown when the clinic portal API cannot load or save patient data.
class PortalException implements Exception {
  const PortalException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// The patient's full profile as defined in MyClinics.
class PatientProfile {
  const PatientProfile({
    required this.patientId,
    required this.fullName,
    required this.mobile,
    this.doctorId,
    this.userId,
    this.whatsapp,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.height,
    this.weight,
    this.bloodPressure,
    this.temperature,
    this.pulse,
    this.respiratoryRate,
    this.spo2,
    this.occupation,
    this.maritalStatus,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactMobile,
    this.allergies = const [],
    this.medicalConditions,
    this.previousSurgeries,
    this.currentMedications,
    this.familyHistory,
    this.patientHistory,
    this.habits,
    this.idType,
    this.idNumber,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.insurancePolicyHolderName,
    this.insuranceValidTill,
    this.referredBy,
    this.howDidYouHear,
    this.notes,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String patientId;
  final String fullName;
  final String mobile;
  final String? doctorId;
  final String? userId;
  final String? whatsapp;
  final String? email;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? height;
  final String? weight;
  final String? bloodPressure;
  final String? temperature;
  final String? pulse;
  final String? respiratoryRate;
  final String? spo2;
  final String? occupation;
  final String? maritalStatus;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactMobile;
  final List<String> allergies;
  final String? medicalConditions;
  final String? previousSurgeries;
  final String? currentMedications;
  final String? familyHistory;
  final String? patientHistory;
  final String? habits;
  final String? idType;
  final String? idNumber;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? insurancePolicyHolderName;
  final String? insuranceValidTill;
  final String? referredBy;
  final String? howDidYouHear;
  final String? notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get locationLabel {
    final parts = [city, state]
        .where((value) => (value ?? '').trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  PatientProfile copyWith({
    String? patientId,
    String? fullName,
    String? mobile,
    String? doctorId,
    String? userId,
    String? whatsapp,
    String? email,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? height,
    String? weight,
    String? bloodPressure,
    String? temperature,
    String? pulse,
    String? respiratoryRate,
    String? spo2,
    String? occupation,
    String? maritalStatus,
    String? emergencyContactName,
    String? emergencyContactRelationship,
    String? emergencyContactMobile,
    List<String>? allergies,
    String? medicalConditions,
    String? previousSurgeries,
    String? currentMedications,
    String? familyHistory,
    String? patientHistory,
    String? habits,
    String? idType,
    String? idNumber,
    String? insuranceProvider,
    String? insurancePolicyNumber,
    String? insurancePolicyHolderName,
    String? insuranceValidTill,
    String? referredBy,
    String? howDidYouHear,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      patientId: patientId ?? this.patientId,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      doctorId: doctorId ?? this.doctorId,
      userId: userId ?? this.userId,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      temperature: temperature ?? this.temperature,
      pulse: pulse ?? this.pulse,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      spo2: spo2 ?? this.spo2,
      occupation: occupation ?? this.occupation,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelationship:
          emergencyContactRelationship ?? this.emergencyContactRelationship,
      emergencyContactMobile:
          emergencyContactMobile ?? this.emergencyContactMobile,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      previousSurgeries: previousSurgeries ?? this.previousSurgeries,
      currentMedications: currentMedications ?? this.currentMedications,
      familyHistory: familyHistory ?? this.familyHistory,
      patientHistory: patientHistory ?? this.patientHistory,
      habits: habits ?? this.habits,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insurancePolicyNumber:
          insurancePolicyNumber ?? this.insurancePolicyNumber,
      insurancePolicyHolderName:
          insurancePolicyHolderName ?? this.insurancePolicyHolderName,
      insuranceValidTill: insuranceValidTill ?? this.insuranceValidTill,
      referredBy: referredBy ?? this.referredBy,
      howDidYouHear: howDidYouHear ?? this.howDidYouHear,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  PatientProfile applyPayload(Map<String, dynamic> payload) {
    List<String> updatedAllergies = allergies;
    if (payload.containsKey('allergies')) {
      final raw = payload['allergies'];
      if (raw is List) {
        updatedAllergies = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    return PatientProfile(
      patientId: patientId,
      fullName: _string(payload['fullName']) ?? fullName,
      mobile: _string(payload['mobile']) ?? mobile,
      doctorId: doctorId,
      userId: userId,
      whatsapp: payload.containsKey('whatsapp') ? _string(payload['whatsapp']) : whatsapp,
      email: payload.containsKey('email') ? _string(payload['email']) : email,
      gender: payload.containsKey('gender') ? _string(payload['gender']) : gender,
      dateOfBirth: payload.containsKey('dateOfBirth') ? _string(payload['dateOfBirth']) : dateOfBirth,
      bloodGroup: payload.containsKey('bloodGroup') ? _string(payload['bloodGroup']) : bloodGroup,
      address: payload.containsKey('address') ? _string(payload['address']) : address,
      city: payload.containsKey('city') ? _string(payload['city']) : city,
      state: payload.containsKey('state') ? _string(payload['state']) : state,
      pincode: payload.containsKey('pincode') ? _string(payload['pincode']) : pincode,
      height: payload.containsKey('height') ? _string(payload['height']) : height,
      weight: payload.containsKey('weight') ? _string(payload['weight']) : weight,
      bloodPressure: payload.containsKey('bloodPressure') ? _string(payload['bloodPressure']) : bloodPressure,
      temperature: payload.containsKey('temperature') ? _string(payload['temperature']) : temperature,
      pulse: payload.containsKey('pulse') ? _string(payload['pulse']) : pulse,
      respiratoryRate: payload.containsKey('respiratoryRate') ? _string(payload['respiratoryRate']) : respiratoryRate,
      spo2: payload.containsKey('spo2') ? _string(payload['spo2']) : spo2,
      occupation: payload.containsKey('occupation') ? _string(payload['occupation']) : occupation,
      maritalStatus: payload.containsKey('maritalStatus') ? _string(payload['maritalStatus']) : maritalStatus,
      emergencyContactName: payload.containsKey('emergencyContactName')
          ? _string(payload['emergencyContactName'])
          : emergencyContactName,
      emergencyContactRelationship: payload.containsKey('emergencyContactRelationship')
          ? _string(payload['emergencyContactRelationship'])
          : emergencyContactRelationship,
      emergencyContactMobile: payload.containsKey('emergencyContactMobile')
          ? _string(payload['emergencyContactMobile'])
          : emergencyContactMobile,
      allergies: updatedAllergies,
      medicalConditions: payload.containsKey('medicalConditions')
          ? _string(payload['medicalConditions'])
          : medicalConditions,
      previousSurgeries: payload.containsKey('previousSurgeries')
          ? _string(payload['previousSurgeries'])
          : previousSurgeries,
      currentMedications: payload.containsKey('currentMedications')
          ? _string(payload['currentMedications'])
          : currentMedications,
      familyHistory: payload.containsKey('familyHistory')
          ? _string(payload['familyHistory'])
          : familyHistory,
      patientHistory: payload.containsKey('patientHistory')
          ? _string(payload['patientHistory'])
          : patientHistory,
      habits: payload.containsKey('habits') ? _string(payload['habits']) : habits,
      idType: payload.containsKey('idType') ? _string(payload['idType']) : idType,
      idNumber: payload.containsKey('idNumber') ? _string(payload['idNumber']) : idNumber,
      insuranceProvider: payload.containsKey('insuranceProvider')
          ? _string(payload['insuranceProvider'])
          : insuranceProvider,
      insurancePolicyNumber: payload.containsKey('insurancePolicyNumber')
          ? _string(payload['insurancePolicyNumber'])
          : insurancePolicyNumber,
      insurancePolicyHolderName: payload.containsKey('insurancePolicyHolderName')
          ? _string(payload['insurancePolicyHolderName'])
          : insurancePolicyHolderName,
      insuranceValidTill: payload.containsKey('insuranceValidTill')
          ? _string(payload['insuranceValidTill'])
          : insuranceValidTill,
      referredBy: referredBy,
      howDidYouHear: howDidYouHear,
      notes: payload.containsKey('notes') ? _string(payload['notes']) : notes,
      status: status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      patientId: _string(json['patientId']) ?? '',
      fullName: _string(json['fullName']) ?? 'Patient',
      mobile: _string(json['mobile']) ?? '',
      doctorId: _string(json['doctorId']),
      userId: _string(json['userId']),
      whatsapp: _string(json['whatsapp']),
      email: _string(json['email']),
      gender: _string(json['gender']),
      dateOfBirth: _string(json['dateOfBirth']),
      bloodGroup: _string(json['bloodGroup']),
      address: _string(json['address']),
      city: _string(json['city']),
      state: _string(json['state']),
      pincode: _string(json['pincode']),
      height: _string(json['height']),
      weight: _string(json['weight']),
      bloodPressure: _string(json['bloodPressure']),
      temperature: _string(json['temperature']),
      pulse: _string(json['pulse']),
      respiratoryRate: _string(json['respiratoryRate']),
      spo2: _string(json['spo2']),
      occupation: _string(json['occupation']),
      maritalStatus: _string(json['maritalStatus']),
      emergencyContactName: _string(json['emergencyContactName']),
      emergencyContactRelationship:
          _string(json['emergencyContactRelationship']),
      emergencyContactMobile: _string(json['emergencyContactMobile']),
      allergies: _stringList(json['allergies']),
      medicalConditions: _string(json['medicalConditions']),
      previousSurgeries: _string(json['previousSurgeries']),
      currentMedications: _string(json['currentMedications']),
      familyHistory: _string(json['familyHistory']),
      patientHistory: _string(json['patientHistory']),
      habits: _string(json['habits']),
      idType: _string(json['idType']),
      idNumber: _string(json['idNumber']),
      insuranceProvider: _string(json['insuranceProvider']),
      insurancePolicyNumber: _string(json['insurancePolicyNumber']),
      insurancePolicyHolderName: _string(json['insurancePolicyHolderName']),
      insuranceValidTill: _string(json['insuranceValidTill']),
      referredBy: _string(json['referredBy']),
      howDidYouHear: _string(json['howDidYouHear']),
      notes: _string(json['notes']),
      status: _string(json['status']) ?? 'active',
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }
}

class AppointmentEntry {
  const AppointmentEntry({
    required this.appointmentId,
    this.patientId,
    this.doctorId,
    this.patientName,
    this.doctorName,
    this.date,
    this.time,
    this.status = 'scheduled',
    this.reason,
    this.notes,
    this.queueStatus,
    this.tokenNumber,
    this.session,
    this.priority = false,
    this.visitType = 'New Visit',
    this.department,
    this.fee,
  });

  final String appointmentId;
  final String? patientId;
  final String? doctorId;
  final String? patientName;
  final String? doctorName;
  final String? date;
  final String? time;
  final String status;
  final String? reason;
  final String? notes;
  final String? queueStatus;
  final int? tokenNumber;
  final String? session;
  final bool priority;
  final String visitType;
  final String? department;
  final double? fee;

  bool get isActive {
    return const {'scheduled', 'confirmed', 'rescheduled'}.contains(status);
  }

  bool get isCompleted =>
      status.toLowerCase() == 'completed' || queueStatus == 'completed';

  bool get isIncompleted =>
      !isCompleted && status.toLowerCase() != 'cancelled';

  DateTime? get scheduledAt {
    final day = _dateTime(date);
    if (day == null) return null;
    final rawTime = (time ?? '').trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(rawTime);
    if (match == null) {
      return DateTime(day.year, day.month, day.day);
    }
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool get isUpcoming {
    if (!isActive) return false;
    final when = scheduledAt;
    if (when == null) return true;
    return when.isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
  }

  AppointmentEntry copyWith({
    String? appointmentId,
    String? patientId,
    String? doctorId,
    String? patientName,
    String? doctorName,
    String? date,
    String? time,
    String? status,
    String? reason,
    String? notes,
    String? queueStatus,
    int? tokenNumber,
    String? session,
    bool? priority,
    String? visitType,
    String? department,
    double? fee,
  }) {
    return AppointmentEntry(
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      queueStatus: queueStatus ?? this.queueStatus,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      session: session ?? this.session,
      priority: priority ?? this.priority,
      visitType: visitType ?? this.visitType,
      department: department ?? this.department,
      fee: fee ?? this.fee,
    );
  }

  factory AppointmentEntry.fromJson(Map<String, dynamic> json) {
    return AppointmentEntry(
      appointmentId: _string(json['appointmentId']) ?? '',
      patientId: _string(json['patientId']),
      doctorId: _string(json['doctorId']),
      patientName: _string(json['patientName']),
      doctorName: _string(json['doctorName']),
      date: _string(json['date']),
      time: _string(json['time']),
      status: _string(json['status']) ?? 'scheduled',
      reason: _string(json['reason']),
      notes: _string(json['notes']),
      queueStatus: _string(json['queueStatus']),
      tokenNumber: _integerOrNull(json['tokenNumber']),
      session: _string(json['session']),
      priority: json['priority'] == true,
      visitType: _string(json['visitType']) ?? 'New Visit',
      department: _string(json['department']),
      fee: _number(json['fee']),
    );
  }
}

class MedicineEntry {
  const MedicineEntry({
    required this.name,
    this.dosage,
    this.frequency,
    this.duration,
    this.instructions,
  });

  final String name;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? instructions;

  factory MedicineEntry.fromJson(Map<String, dynamic> json) {
    return MedicineEntry(
      name: _string(json['name']) ?? 'Medicine',
      dosage: _string(json['dosage']),
      frequency: _string(json['frequency']),
      duration: _string(json['duration']),
      instructions: _string(json['instructions']),
    );
  }
}

class PrescriptionEntry {
  const PrescriptionEntry({
    required this.prescriptionId,
    this.visitDate,
    this.diagnosis,
    this.notes,
    this.doctorName,
    this.createdAt,
    this.medicines = const [],
  });

  final String prescriptionId;
  final String? visitDate;
  final String? diagnosis;
  final String? notes;
  final String? doctorName;
  final DateTime? createdAt;
  final List<MedicineEntry> medicines;

  factory PrescriptionEntry.fromJson(Map<String, dynamic> json) {
    final medicines = <MedicineEntry>[];
    final raw = json['medicines'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          medicines.add(MedicineEntry.fromJson(item));
        }
      }
    }
    return PrescriptionEntry(
      prescriptionId: _string(json['prescriptionId']) ?? '',
      visitDate: _string(json['visitDate']),
      diagnosis: _string(json['diagnosis']),
      notes: _string(json['notes']),
      doctorName: _string(json['doctorName']),
      createdAt: _dateTime(json['createdAt']),
      medicines: medicines,
    );
  }
}

class BillItemEntry {
  const BillItemEntry({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.taxPercent = 0,
    this.lineTotal = 0,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxPercent;
  final double lineTotal;

  factory BillItemEntry.fromJson(Map<String, dynamic> json) {
    return BillItemEntry(
      description: _string(json['description']) ?? 'Service',
      quantity: _number(json['quantity'], fallback: 1),
      unitPrice: _number(json['unitPrice']),
      discount: _number(json['discount']),
      taxPercent: _number(json['taxPercent']),
      lineTotal: _number(json['lineTotal']),
    );
  }
}

class BillEntry {
  const BillEntry({
    required this.billId,
    required this.billNumber,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.taxPercent = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.status = 'issued',
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.paymentStatus = 'unpaid',
    this.paymentType,
    this.paymentMethod,
    this.invoiceDate,
    this.dueDate,
    this.paidAt,
    this.doctorName,
    this.notes,
    this.reference,
    this.createdAt,
  });

  final String billId;
  final String billNumber;
  final List<BillItemEntry> items;
  final double subtotal;
  final double discount;
  final double taxPercent;
  final double taxAmount;
  final double total;
  final String status;
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final String? paymentType;
  final String? paymentMethod;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? doctorName;
  final String? notes;
  final String? reference;
  final DateTime? createdAt;

  bool get isPaid =>
      status == 'paid' || paymentStatus == 'paid' || balanceDue <= 0.009;
  bool get isVoid => status == 'void';
  bool get isDraft => status == 'draft';

  double get outstanding => isPaid || isVoid ? 0 : balanceDue;

  String get displayStatus {
    if (isVoid) return 'Void';
    if (isDraft) return 'Draft';
    if (isPaid) return 'Paid';
    if (paymentStatus == 'partial' || amountPaid > 0) return 'Partially Paid';
    return 'Unpaid';
  }

  BillEntry copyWith({
    String? billId,
    String? billNumber,
    List<BillItemEntry>? items,
    double? subtotal,
    double? discount,
    double? taxPercent,
    double? taxAmount,
    double? total,
    String? status,
    double? amountPaid,
    double? balanceDue,
    String? paymentStatus,
    String? paymentType,
    String? paymentMethod,
    DateTime? invoiceDate,
    DateTime? dueDate,
    DateTime? paidAt,
    String? doctorName,
    String? notes,
    String? reference,
    DateTime? createdAt,
  }) {
    return BillEntry(
      billId: billId ?? this.billId,
      billNumber: billNumber ?? this.billNumber,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxPercent: taxPercent ?? this.taxPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      status: status ?? this.status,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentType: paymentType ?? this.paymentType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      doctorName: doctorName ?? this.doctorName,
      notes: notes ?? this.notes,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BillEntry.fromJson(Map<String, dynamic> json) {
    final items = <BillItemEntry>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(BillItemEntry.fromJson(item));
        }
      }
    }
    final total = _number(json['total']);
    final amountPaid = _number(json['amountPaid']);
    final status = _string(json['status']) ?? 'issued';
    final paymentStatus = _string(json['paymentStatus']) ??
        (status == 'paid' ? 'paid' : 'unpaid');
    final balanceDue = json.containsKey('balanceDue')
        ? _number(json['balanceDue'])
        : (total - amountPaid);
    return BillEntry(
      billId: _string(json['billId']) ?? '',
      billNumber: _string(json['billNumber']) ?? 'Bill',
      items: items,
      subtotal: _number(json['subtotal']),
      discount: _number(json['discount']),
      taxPercent: _number(json['taxPercent']),
      taxAmount: _number(json['taxAmount']),
      total: total,
      status: status,
      amountPaid: amountPaid,
      balanceDue: balanceDue,
      paymentStatus: paymentStatus,
      paymentType: _string(json['paymentType']),
      paymentMethod: _string(json['paymentMethod']),
      invoiceDate: _dateTime(json['invoiceDate']) ??
          _dateTime(json['createdAt']),
      dueDate: _dateTime(json['dueDate']),
      paidAt: _dateTime(json['paidAt']),
      doctorName: _string(json['doctorName']),
      notes: _string(json['notes']),
      reference: _string(json['reference']),
      createdAt: _dateTime(json['createdAt']),
    );
  }
}

class ClinicInfo {
  const ClinicInfo({
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.website,
    this.description,
    this.workingHoursOpen,
    this.workingHoursClose,
    this.currency = '₹',
    this.clinicType,
    this.registrationNumber,
    this.establishedYear,
    this.whatsapp,
    this.emergencyContact,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? website;
  final String? description;
  final String? workingHoursOpen;
  final String? workingHoursClose;
  final String currency;
  final String? clinicType;
  final String? registrationNumber;
  final String? establishedYear;
  final String? whatsapp;
  final String? emergencyContact;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;

  String get fullAddress {
    final profileParts = [
      addressLine1,
      addressLine2,
      city,
      state,
      pincode,
    ].where((value) => (value ?? '').trim().isNotEmpty).toList();
    if (profileParts.isNotEmpty) return profileParts.join(', ');
    return (address ?? '').trim();
  }

  String get workingHours {
    final open = (workingHoursOpen ?? '').trim();
    final close = (workingHoursClose ?? '').trim();
    if (open.isEmpty && close.isEmpty) return '—';
    return '$open - $close';
  }

  factory ClinicInfo.fromJson(Map<String, dynamic> json) {
    final settings = _map(json['settings']);
    final workingHours = _map(settings?['workingHours']);
    final profile = _map(json['profile']);
    return ClinicInfo(
      name: _string(json['name']) ?? 'My Clinic',
      phone: _string(json['phone']),
      email: _string(json['email']),
      address: _string(json['address']),
      website: _string(json['website']),
      description: _string(json['description']),
      workingHoursOpen: _string(workingHours?['open']),
      workingHoursClose: _string(workingHours?['close']),
      currency: _string(settings?['currency']) ?? '₹',
      clinicType: _string(profile?['clinicType']),
      registrationNumber: _string(profile?['registrationNumber']),
      establishedYear: _string(profile?['establishedYear']),
      whatsapp: _string(profile?['whatsapp']),
      emergencyContact: _string(profile?['emergencyContact']),
      addressLine1: _string(profile?['addressLine1']),
      addressLine2: _string(profile?['addressLine2']),
      city: _string(profile?['city']),
      state: _string(profile?['state']),
      pincode: _string(profile?['pincode']),
    );
  }
}

class PortalDashboardData {
  const PortalDashboardData({
    required this.patient,
    this.appointments = const [],
    this.prescriptions = const [],
    this.bills = const [],
    this.files = const [],
  });

  final PatientProfile patient;
  final List<AppointmentEntry> appointments;
  final List<PrescriptionEntry> prescriptions;
  final List<BillEntry> bills;
  final List<MedicalRecordFileEntry> files;

  List<AppointmentEntry> get upcomingAppointments {
    final upcoming = appointments.where((item) => item.isUpcoming).toList()
      ..sort((a, b) => (a.scheduledAt ?? DateTime(9999))
          .compareTo(b.scheduledAt ?? DateTime(9999)));
    return upcoming;
  }

  double get outstandingTotal => bills.fold<double>(
        0,
        (sum, bill) => sum + bill.outstanding,
      );

  int get unpaidBillCount =>
      bills.where((bill) => !bill.isPaid && !bill.isVoid).length;

  int get documentsCount => files.length;

  int get recordsCount => appointments.length + prescriptions.length;
}

/// Reads the authenticated patient's profile, appointments, prescriptions,
/// bills and documents from the clinic portal, backed by MyClinics datasets.
class PatientPortalService {
  PatientPortalService({required this.session, http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final PatientSession session;
  final http.Client _client;
  final bool _ownsClient;

  static const _timeout = Duration(seconds: 60);


  void dispose() {
    if (_ownsClient) _client.close();
  }

  String get _base => '/api/clinics/${session.clinicId}';

  // ---------------------------------------------------------------------------
  // Service Methods
  // ---------------------------------------------------------------------------

  Future<PortalDashboardData> fetchDashboard() async {
    final profileFuture = fetchProfile();
    final appointmentsFuture = fetchAppointments();
    final prescriptionsFuture = fetchPrescriptions();
    final billsFuture = fetchBills();
    final filesFuture = _fetchMedicalRecordFiles();

    return PortalDashboardData(
      patient: await profileFuture,
      appointments: await appointmentsFuture,
      prescriptions: await prescriptionsFuture,
      bills: await billsFuture,
      files: await filesFuture,
    );
  }

  Future<List<MedicalRecordFileEntry>> _fetchMedicalRecordFiles({
    int limit = 100,
  }) async {
    final encodedPatient = Uri.encodeQueryComponent(_patientId);
    final json = await _requestJson(
      'GET',
      '$_base/medical-record?patientId=$encodedPatient&limit=$limit',
    );
    return _listOfMaps(json['files'])
        .map(MedicalRecordFileEntry.fromJson)
        .where((item) => item.fileId.isNotEmpty)
        .toList();
  }

  Future<PatientProfile> fetchProfile() async {
    _ensurePatient();
    final json = await _requestJson('GET', '$_base/me/patient');
    return PatientProfile.fromJson(json);
  }

  Future<List<AppointmentEntry>> fetchAppointments({int limit = 50}) async {
    _ensurePatient();
    final json = await _requestJson(
      'GET',
      '$_base/me/appointments?limit=$limit',
    );
    return _listOfMaps(json['items'])
        .map(AppointmentEntry.fromJson)
        .where((item) => item.appointmentId.isNotEmpty)
        .toList();
  }

  /// Fetches the active doctors belonging to this clinic.
  ///
  /// Guarantees patients only see verified doctors (no staff or non-doctor profiles).
  Future<List<DoctorEntry>> fetchDoctors({bool activeOnly = true}) async {
    final query = activeOnly ? '?status=active' : '';
    final json = await _requestJson('GET', '$_base/doctors$query');
    final rawList = json['items'] ?? json['doctors'] ?? json;
    return _listOfMaps(rawList)
        .map(DoctorEntry.fromJson)
        .where((d) => d.doctorId.isNotEmpty && (!activeOnly || d.isActive))
        .toList();
  }

  /// Books a new appointment through the clinic API and returns the record
  /// created by the server (including its real token number and queue state).
  Future<AppointmentEntry> bookAppointment(AppointmentBookingInput input) async {
    _ensurePatient();
    final json = await _requestJson(
      'POST',
      '$_base/me/appointments',
      payload: {
        'doctorId': input.doctorId,
        'date': input.date,
        'time': input.time,
        'reason': input.reason,
        'notes': input.notes ??
            (input.symptoms != null ? 'Symptoms: ${input.symptoms}' : null),
      },
    );
    final appointment = AppointmentEntry.fromJson(json);
    return appointment.copyWith(
      doctorName: appointment.doctorName ?? input.doctorName,
      department: appointment.department ?? input.department,
      visitType: input.visitType,
      fee: input.consultationFee,
    );
  }

  Future<List<PrescriptionEntry>> fetchPrescriptions({int limit = 50}) async {
    _ensurePatient();
    final json = await _requestJson(
      'GET',
      '$_base/me/prescriptions?limit=$limit',
    );
    return _listOfMaps(json['items'])
        .map(PrescriptionEntry.fromJson)
        .where((item) => item.prescriptionId.isNotEmpty)
        .toList();
  }

  Future<List<BillEntry>> fetchBills({int limit = 50}) async {
    _ensurePatient();
    final json = await _requestJson('GET', '$_base/me/bills?limit=$limit');
    return _listOfMaps(json['items'])
        .map(BillEntry.fromJson)
        .where((item) => item.billId.isNotEmpty)
        .toList();
  }

  Future<ClinicInfo> fetchClinic() async {
    final json = await _requestJson('GET', '/api/clinics/me');
    return ClinicInfo.fromJson(json);
  }

  Future<PatientProfile> updateProfile(Map<String, dynamic> payload) async {
    _ensurePatient();
    final json = await _requestJson(
      'PATCH',
      '$_base/patients/$_patientId',
      payload: payload,
    );
    return PatientProfile.fromJson(json);
  }

  String get _patientId {
    _ensurePatient();
    return session.patientId!.trim();
  }

  void _ensurePatient() {
    final patientId = (session.patientId ?? '').trim();
    if (patientId.isEmpty) {
      throw const PortalException(
        "This account isn't linked to a patient profile. Please contact your clinic.",
      );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? payload,
    int attempt = 0,
    bool authRetried = false,
  }) async {
    if (SessionManager.instance.isSignedIn) {
      await SessionManager.instance.maybeRefresh();
    }
    final uri = Uri.parse('${AppConfig.backendUrl}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${SessionManager.instance.tokenFor(session)}',
    };

    try {
      final http.Response response;
      if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(payload ?? const {}))
            .timeout(_timeout);
      } else if (method == 'PATCH') {
        response = await _client
            .patch(uri, headers: headers, body: jsonEncode(payload ?? const {}))
            .timeout(_timeout);
      } else {
        response = await _client.get(uri, headers: headers).timeout(_timeout);
      }

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}

      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        return body ?? const {};
      }

      // An expired token is recoverable: rotate it once and replay the call.
      // Only a refresh the server rejects means the session is really gone.
      if (status == 401 &&
          !authRetried &&
          SessionManager.instance.isSignedIn) {
        final refreshed = await SessionManager.instance.refresh();
        if (refreshed != null) {
          return _requestJson(
            method,
            path,
            payload: payload,
            attempt: attempt,
            authRetried: true,
          );
        }
      }

      final message = _extractMessage(body, response.body, status);
      throw PortalException(message, statusCode: status);
    } on TimeoutException {
      if (method == 'GET' && attempt < 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        return _requestJson(method, path, payload: payload, attempt: attempt + 1);
      }
      throw const PortalException(
        'Request timed out. The server is taking too long to respond. Please try again in a moment.',
      );
    } on http.ClientException catch (error) {
      final text = error.message.toLowerCase();
      final looksLikeNetwork = text.contains('socket') ||
          text.contains('failed host lookup') ||
          text.contains('network') ||
          text.contains('connection refused') ||
          text.contains('connection closed') ||
          text.contains('connection reset') ||
          text.contains('timed out');
      if (method == 'GET' && looksLikeNetwork && attempt < 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        return _requestJson(method, path, payload: payload, attempt: attempt + 1);
      }
      throw PortalException(
        looksLikeNetwork
            ? 'Could not reach the clinic server. Please check your connection and try again.'
            : 'Could not connect to the clinic server. Please try again.',
      );
    } catch (error) {
      if (error is PortalException) rethrow;
      final text = error.toString().toLowerCase();
      final looksLikeNetwork = text.contains('socketexception') ||
          text.contains('failed host lookup') ||
          text.contains('network is unreachable') ||
          text.contains('connection refused') ||
          text.contains('connection reset') ||
          text.contains('timed out');
      if (method == 'GET' && looksLikeNetwork && attempt < 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        return _requestJson(method, path, payload: payload, attempt: attempt + 1);
      }
      throw PortalException(
        looksLikeNetwork
            ? 'Could not reach the clinic server. Please check your connection and try again.'
            : 'Something went wrong. Please try again.',
      );
    }
  }

  String _extractMessage(Map<String, dynamic>? body, String raw, int status) {
    if (body != null) {
      final message = _string(body['message']) ??
          _string(body['error']) ??
          _string(body['msg']);
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    if (status == 401) return 'Session expired. Please sign in again.';
    if (status == 403) return 'You do not have permission to perform this action.';
    if (status == 404) return 'The requested patient data was not found.';
    if (raw.trim().isNotEmpty && raw.length < 160) return raw.trim();
    return 'Operation failed (status $status).';
  }
}

// -----------------------------------------------------------------------------
// JSON Helpers
// -----------------------------------------------------------------------------

String? _string(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString().trim();
}

List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map(_string)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}

double _number(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int? _integerOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(key.toString(), val),
    );
  }
  return null;
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return const [];
  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    final map = _map(item);
    if (map != null) result.add(map);
  }
  return result;
}

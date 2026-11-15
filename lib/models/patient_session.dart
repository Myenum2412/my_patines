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
}

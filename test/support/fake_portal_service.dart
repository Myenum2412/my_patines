import 'package:my_patines/services/patient_portal_service.dart';
import 'package:my_patines/services/records_service.dart';

class FakePortalService extends PatientPortalService {
  FakePortalService({
    required super.session,
    this.patient,
    this.appointments = const [],
    this.prescriptions = const [],
    this.bills = const [],
    this.files = const [],
    this.doctors = const [],
    this.clinic,
    this.bookedAppointment,
  });

  PatientProfile? patient;
  List<AppointmentEntry> appointments;
  List<PrescriptionEntry> prescriptions;
  List<BillEntry> bills;
  List<MedicalRecordFileEntry> files;
  List<DoctorEntry> doctors;
  ClinicInfo? clinic;
  AppointmentEntry? bookedAppointment;

  @override
  Future<PortalDashboardData> fetchDashboard() async {
    return PortalDashboardData(
      patient: await fetchProfile(),
      appointments: await fetchAppointments(),
      prescriptions: await fetchPrescriptions(),
      bills: await fetchBills(),
      files: files,
    );
  }

  @override
  Future<PatientProfile> fetchProfile() async => patient!;

  @override
  Future<List<AppointmentEntry>> fetchAppointments({int limit = 50}) async =>
      appointments;

  @override
  Future<List<PrescriptionEntry>> fetchPrescriptions({int limit = 50}) async =>
      prescriptions;

  @override
  Future<List<BillEntry>> fetchBills({int limit = 50}) async => bills;

  @override
  Future<List<DoctorEntry>> fetchDoctors({bool activeOnly = true}) async =>
      doctors;

  @override
  Future<ClinicInfo> fetchClinic() async =>
      clinic ??
      const ClinicInfo(
        name: 'Test Clinic',
        phone: '1234567890',
        email: 'clinic@example.com',
      );

  @override
  Future<AppointmentEntry> bookAppointment(AppointmentBookingInput input) async {
    return bookedAppointment ??
        AppointmentEntry(
          appointmentId: 'apt_new',
          patientId: session.patientId,
          doctorId: input.doctorId,
          doctorName: input.doctorName,
          date: input.date,
          time: input.time,
          status: 'scheduled',
          reason: input.reason,
          tokenNumber: 12,
          department: input.department,
          visitType: input.visitType,
        );
  }

  @override
  Future<PatientProfile> updateProfile(Map<String, dynamic> payload) async {
    patient = patient!.applyPayload(payload);
    return patient!;
  }
}

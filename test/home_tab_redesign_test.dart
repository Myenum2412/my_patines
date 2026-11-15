import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/home_tab.dart';
import 'package:my_patines/services/patient_portal_service.dart';

import 'support/fake_portal_service.dart';

void main() {
  const testSession = PatientSession(
    clinicId: 'clc_test',
    token: 'test_token',
    patientId: 'pat_test',
    name: 'John Patient',
    email: 'john@example.com',
    clinicName: 'City Clinic',
  );

  testWidgets('HomeTab renders dashboard with real clinic data', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final service = FakePortalService(
      session: testSession,
      patient: const PatientProfile(
        patientId: 'pat_test',
        fullName: 'John Patient',
        mobile: '9999999999',
        status: 'active',
      ),
      clinic: const ClinicInfo(name: 'City Clinic'),
      doctors: const [
        DoctorEntry(
          doctorId: 'doc_1',
          name: 'Anita Rao',
          specialization: 'General Medicine',
          status: 'active',
        ),
      ],
      appointments: const [
        AppointmentEntry(
          appointmentId: 'apt_1',
          doctorName: 'Dr. Anita Rao',
          date: '2099-01-01',
          time: '10:00',
          status: 'scheduled',
          tokenNumber: 3,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTab(
            session: testSession,
            onOpenTab: (_) {},
            service: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PATIENT PORTAL'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Welcome, John'), findsOneWidget);
    expect(find.text('ONLINE APPOINTMENT'), findsOneWidget);
    expect(find.text('Book Doctor Appointment'), findsOneWidget);
    expect(find.text('Next appointment'), findsOneWidget);
    expect(find.text('Our Doctors'), findsOneWidget);
    expect(find.textContaining('Dr. Anita Rao'), findsWidgets);

    await tester.tap(find.text('Book Appointment').first);
    await tester.pumpAndSettle();
    expect(find.text('1. Choose Doctor'), findsOneWidget);
  });
}

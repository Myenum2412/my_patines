import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/appointments_tab.dart';
import 'package:my_patines/services/patient_portal_service.dart';

import 'support/fake_portal_service.dart';

void main() {
  const testSession = PatientSession(
    clinicId: 'clc_test',
    token: 'tok_test',
    patientId: 'pat_001',
    name: 'John Patient',
    email: 'john@example.com',
    clinicName: 'Test Clinic',
  );

  testWidgets('AppointmentsTab renders today tokens and status filters', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final service = FakePortalService(
      session: testSession,
      patient: const PatientProfile(
        patientId: 'pat_001',
        fullName: 'John Patient',
        mobile: '9999999999',
      ),
      appointments: [
        AppointmentEntry(
          appointmentId: 'apt_1',
          doctorName: 'Dr. Anita Rao',
          department: 'General Medicine',
          date: today,
          time: '09:30',
          status: 'completed',
          tokenNumber: 4,
        ),
        AppointmentEntry(
          appointmentId: 'apt_2',
          doctorName: 'Dr. Anita Rao',
          department: 'General Medicine',
          date: today,
          time: '10:30',
          status: 'scheduled',
          tokenNumber: 9,
          reason: 'Follow-up',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentsTab(session: testSession, service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Today's tokens"), findsOneWidget);
    expect(find.text("Today's Tokens (2)"), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Waiting'), findsWidgets);
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('#9'), findsOneWidget);

    await tester.tap(find.text('Waiting').last);
    await tester.pumpAndSettle();
    expect(find.text('Appointment Token Slip'), findsOneWidget);
    expect(find.text('ASSIGNED TOKEN'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment Token Slip'), findsNothing);
  });
}

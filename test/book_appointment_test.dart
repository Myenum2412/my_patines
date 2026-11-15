import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/book_appointment_page.dart';
import 'package:my_patines/screens/doctors_sheet.dart';
import 'package:my_patines/services/patient_portal_service.dart';

import 'support/fake_portal_service.dart';

void main() {
  const testSession = PatientSession(
    clinicId: 'clc_test',
    token: 'test_token',
    patientId: 'pat_test',
    name: 'John Patient',
    email: 'john@example.com',
    clinicName: 'Test Clinic',
  );

  FakePortalService makeService() => FakePortalService(
        session: testSession,
        patient: const PatientProfile(
          patientId: 'pat_test',
          fullName: 'John Patient',
          mobile: '9999999999',
        ),
        doctors: const [
          DoctorEntry(
            doctorId: 'doc_1',
            name: 'Anita Rao',
            specialization: 'General Medicine',
            department: 'General Medicine',
            experienceYears: 12,
            status: 'active',
          ),
          DoctorEntry(
            doctorId: 'doc_2',
            name: 'Priya Nair',
            specialization: 'Pediatrics',
            department: 'Pediatrics',
            experienceYears: 9,
            status: 'active',
          ),
        ],
      );

  testWidgets('BookAppointmentPage renders real doctors and books appointment',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    bool booked = false;
    final service = makeService();

    await tester.pumpWidget(
      MaterialApp(
        home: BookAppointmentPage(
          session: testSession,
          onAppointmentBooked: () => booked = true,
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Book Appointment'), findsOneWidget);
    expect(find.text('Booking for You'), findsOneWidget);
    expect(find.text('John Patient'), findsOneWidget);
    expect(find.text('1. Choose Doctor'), findsOneWidget);
    expect(find.textContaining('Dr. Anita Rao'), findsWidgets);
    expect(find.textContaining('Dr. Priya Nair'), findsWidgets);

    final reasonFinder = find.widgetWithText(
      TextField,
      'e.g. Regular BP checkup, recurring fever, dental pain',
    );
    await tester.enterText(reasonFinder, 'Routine follow-up consultation');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm & Book Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment Booked!'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(booked, isTrue);
  });

  testWidgets('showDoctorsSheet displays clinic doctors from service',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final service = makeService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDoctorsSheet(
                    context: context,
                    session: testSession,
                    service: service,
                  );
                },
                child: const Text('Open Doctors'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Doctors'));
    await tester.pumpAndSettle();

    expect(find.text('Clinic Doctors'), findsOneWidget);
    expect(find.text('Dr. Anita Rao'), findsOneWidget);
    expect(find.text('Dr. Priya Nair'), findsOneWidget);
  });
}

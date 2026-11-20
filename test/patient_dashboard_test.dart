import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/billing_tab.dart';
import 'package:my_patines/screens/home_tab.dart';
import 'package:my_patines/screens/profile_tab.dart';
import 'package:my_patines/services/patient_portal_service.dart';
import 'package:my_patines/widgets/details_sheet.dart';

import 'support/fake_portal_service.dart';

void main() {
  const testSession = PatientSession(
    clinicId: 'clc_test',
    token: 'test_token',
    patientId: 'pat_001',
    name: 'John Patient',
    email: 'john@example.com',
    clinicName: 'City Clinic',
  );

  testWidgets('showDetailsSheet opens, renders cleanly without overflow, and closes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDetailsSheet(
                    context: context,
                    title: 'Invoice Details',
                    subtitle: 'INV-1001  •  ₹1,000',
                    icon: Icons.receipt_long_outlined,
                    children: const [
                      DetailSection(
                        title: 'Summary',
                        children: [
                          DetailField(label: 'Doctor', value: 'Dr. Anita Rao'),
                          DetailField(label: 'Total', value: '₹1,000'),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open Details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Details'));
    await tester.pumpAndSettle();

    expect(find.text('Invoice Details'), findsOneWidget);
    expect(find.text('Dr. Anita Rao'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Invoice Details'), findsNothing);
  });

  testWidgets('Home, Billing and Profile tabs render real session data',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final service = FakePortalService(
      session: testSession,
      patient: const PatientProfile(
        patientId: 'pat_001',
        fullName: 'John Patient',
        mobile: '9999999999',
        email: 'john@example.com',
        status: 'active',
      ),
      clinic: const ClinicInfo(name: 'City Clinic', phone: '1234567890'),
      appointments: const [
        AppointmentEntry(
          appointmentId: 'apt_1',
          doctorName: 'Dr. Anita Rao',
          date: '2099-01-01',
          time: '10:00',
          status: 'scheduled',
          tokenNumber: 5,
        ),
      ],
      bills: [
        BillEntry(
          billId: 'bil_1',
          billNumber: 'INV-1001',
          items: const [
            BillItemEntry(
              description: 'Consultation',
              quantity: 1,
              unitPrice: 500,
              lineTotal: 500,
            ),
          ],
          subtotal: 500,
          total: 500,
          amountPaid: 500,
          balanceDue: 0,
          status: 'paid',
          paymentStatus: 'paid',
          invoiceDate: DateTime(2026, 11, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Home'),
                    Tab(text: 'Billing'),
                    Tab(text: 'Profile'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      HomeTab(
                        session: testSession,
                        onOpenTab: (_) {},
                        service: service,
                      ),
                      BillingTab(session: testSession, service: service),
                      ProfileTab(session: testSession, service: service),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('John'), findsOneWidget);
    expect(find.text('Book a visit'), findsOneWidget);

    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();
    expect(find.text('Billing overview'), findsOneWidget);
    expect(find.text('INV-1001'), findsWidgets);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('John Patient'), findsWidgets);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Contact & Address'), findsOneWidget);
    expect(find.text('Medical & Health'), findsOneWidget);
    expect(find.text('Clinic Details'), findsOneWidget);
  });
}

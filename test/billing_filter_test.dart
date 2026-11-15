import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/billing_tab.dart';
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

  testWidgets('BillingTab renders real invoices and filters', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final service = FakePortalService(
      session: testSession,
      patient: const PatientProfile(
        patientId: 'pat_001',
        fullName: 'John Patient',
        mobile: '9999999999',
      ),
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
        BillEntry(
          billId: 'bil_2',
          billNumber: 'INV-1002',
          items: const [
            BillItemEntry(
              description: 'Lab Test',
              quantity: 1,
              unitPrice: 800,
              lineTotal: 800,
            ),
          ],
          subtotal: 800,
          total: 800,
          amountPaid: 0,
          balanceDue: 800,
          status: 'issued',
          paymentStatus: 'unpaid',
          invoiceDate: DateTime(2026, 11, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillingTab(session: testSession, service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Billing overview'), findsOneWidget);
    expect(find.text('Settlement ratio'), findsOneWidget);
    expect(find.text('INV-1001'), findsOneWidget);
    expect(find.text('INV-1002'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'INV-1001');
    await tester.pumpAndSettle();
    expect(find.text('INV-1001'), findsWidgets);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Search by invoice #, item, or notes...'), findsOneWidget);
  });
}

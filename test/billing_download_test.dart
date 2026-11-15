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
    clinicName: 'City Clinic',
  );

  testWidgets('BillingTab allows viewing and downloading PDF invoices', (tester) async {
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
          billId: 'bil_1001',
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
          body: BillingTab(session: testSession, service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Billing overview'), findsOneWidget);
    expect(find.text('INV-1001'), findsOneWidget);

    await tester.tap(find.text('INV-1001').first);
    await tester.pumpAndSettle();

    expect(find.text('INVOICE DETAILS'), findsOneWidget);
    expect(find.text('Download PDF Invoice'), findsOneWidget);
    expect(find.byTooltip('Preview PDF'), findsOneWidget);

    await tester.tap(find.text('Download PDF Invoice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('INV-1001.pdf'), findsWidgets);
    expect(find.text('View'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('PDF Invoice Document'), findsOneWidget);
    expect(find.text('Save to Downloads'), findsOneWidget);
  });
}

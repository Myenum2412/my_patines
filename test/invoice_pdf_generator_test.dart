import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/services/patient_portal_service.dart';
import 'package:my_patines/utils/invoice_pdf_generator.dart';

void main() {
  test('generateInvoicePdf generates valid PDF binary data', () async {
    const session = PatientSession(
      clinicId: 'clc_test',
      token: 'tok_test',
      patientId: 'pat_001',
      name: 'John Patient',
      email: 'john@example.com',
      clinicName: 'City Clinic',
    );

    final bill = BillEntry(
      billId: 'bill_001',
      billNumber: 'INV-1001',
      items: const [
        BillItemEntry(
          description: 'General Physician Consultation',
          quantity: 1,
          unitPrice: 650,
          lineTotal: 650,
        ),
        BillItemEntry(
          description: 'Complete Blood Count (CBC)',
          quantity: 1,
          unitPrice: 450,
          lineTotal: 450,
        ),
      ],
      subtotal: 1100,
      taxAmount: 55,
      taxPercent: 5,
      discount: 50,
      total: 1105,
      amountPaid: 1105,
      balanceDue: 0,
      status: 'paid',
      paymentStatus: 'paid',
      paymentMethod: 'UPI / Online',
      invoiceDate: DateTime(2026, 10, 12),
      dueDate: DateTime(2026, 10, 26),
      doctorName: 'Dr. Anita Rao',
    );

    final Uint8List pdfBytes = await generateInvoicePdf(
      bill: bill,
      session: session,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);

    // Standard PDF header signature is %PDF-
    final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
    expect(header, equals('%PDF-'));
  });
}

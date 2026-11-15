import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import 'formatters.dart';

/// Generates a clean, Apple-styled itemized PDF invoice for a patient bill.
///
/// Designed with standard Helvetica fonts for 100% cross-platform compatibility
/// without missing glyph issues.
Future<Uint8List> generateInvoicePdf({
  required BillEntry bill,
  required PatientSession session,
  PatientProfile? profile,
}) async {
  final clinicTitle = (session.clinicName ?? '').trim().isNotEmpty
      ? session.clinicName!.trim()
      : 'Healthcare Clinic';

  final patientName = profile != null && profile.fullName.trim().isNotEmpty
      ? profile.fullName.trim()
      : ((session.name ?? '').trim().isNotEmpty
          ? session.name!.trim()
          : 'Patient');

  final patientId = (session.patientId ?? '').trim().isNotEmpty
      ? session.patientId!.trim()
      : '-';

  final email = (session.email ?? '').trim();

  final pdf = pw.Document(
    title: 'Invoice_${bill.billNumber}',
    author: clinicTitle,
  );

  String fmtMoney(num? amount) {
    final formatted = formatMoney(amount, alwaysDecimals: true);
    return formatted.replaceAll('₹', 'Rs. ');
  }

  String fmtDate(DateTime? dt) => formatDate(dt, fallback: '-');

  final isPaid = bill.isPaid;
  final statusLabel = bill.displayStatus.toUpperCase();

  // Palette - Apple minimalist
  const colorPrimary = PdfColor.fromInt(0xFF1D1D1F);
  const colorSecondary = PdfColor.fromInt(0xFF6E6E73);
  const colorBorder = PdfColor.fromInt(0xFFE5E5EA);
  const colorHeaderBg = PdfColor.fromInt(0xFFF5F5F7);
  const colorAccent = PdfColor.fromInt(0xFF0071E3);
  const colorSuccess = PdfColor.fromInt(0xFF34C759);
  const colorWarning = PdfColor.fromInt(0xFFFF9500);

  final statusColor = isPaid ? colorSuccess : colorWarning;

  final items = bill.items.isNotEmpty
      ? bill.items
      : [
          BillItemEntry(
            description: 'Medical Consultation & Hospital Care',
            quantity: 1,
            unitPrice: bill.total > 0 ? bill.total : 500,
            lineTotal: bill.total > 0 ? bill.total : 500,
          ),
        ];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // TOP HEADER: Clinic Branding & Document Title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        clinicTitle,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: colorPrimary,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Patient Billing & Accounts Department',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: colorSecondary,
                        ),
                      ),
                      if (session.clinicId.isNotEmpty)
                        pw.Text(
                          'Clinic ID: ${session.clinicId}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: colorSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: isPaid
                            ? const PdfColor.fromInt(0xFFF2FBF4)
                            : const PdfColor.fromInt(0xFFFFF9ED),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: statusColor, width: 1),
                      ),
                      child: pw.Text(
                        statusLabel,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: colorPrimary,
                      ),
                    ),
                    pw.Text(
                      '# ${bill.billNumber}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: colorAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 14),
            pw.Divider(color: colorBorder, thickness: 0.8),
            pw.SizedBox(height: 12),

            // TWO-COLUMN INVOICE METADATA
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Billed To (Patient)
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: colorHeaderBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: colorBorder, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED TO',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: colorSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          patientName,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: colorPrimary,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Patient ID: $patientId',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: colorSecondary,
                          ),
                        ),
                        if (email.isNotEmpty)
                          pw.Text(
                            'Email: $email',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: colorSecondary,
                            ),
                          ),
                        if (profile != null && profile.mobile.trim().isNotEmpty)
                          pw.Text(
                            'Phone: ${profile.mobile.trim()}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: colorSecondary,
                            ),
                          ),
                        if (profile != null &&
                            profile.address != null &&
                            profile.address!.trim().isNotEmpty)
                          pw.Text(
                            'Address: ${profile.address!.trim()}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: colorSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                // Invoice Details
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: colorHeaderBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: colorBorder, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'INVOICE DETAILS',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: colorSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        _buildMetaRow('Invoice Date:', fmtDate(bill.invoiceDate ?? bill.createdAt)),
                        _buildMetaRow('Due Date:', fmtDate(bill.dueDate)),
                        _buildMetaRow(
                          'Doctor:',
                          bill.doctorName?.trim().isNotEmpty == true
                              ? bill.doctorName!
                              : '—',
                        ),
                        _buildMetaRow(
                          'Payment Method:',
                          bill.paymentMethod ?? (isPaid ? 'UPI / Online' : 'Pending Payment'),
                        ),
                        if (bill.reference != null && bill.reference!.trim().isNotEmpty)
                          _buildMetaRow('Reference:', bill.reference!),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            // ITEMIZED TABLE
            pw.Text(
              'SERVICES & CHARGES',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: colorSecondary,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),

            // Combined Table Container with uniform border
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: colorBorder, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  // Table Header
                  pw.Container(
                    color: colorHeaderBg,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            'DESCRIPTION',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: colorSecondary,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            'QTY',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: colorSecondary,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'RATE',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: colorSecondary,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'AMOUNT',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: colorSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Divider(color: colorBorder, height: 1, thickness: 0.8),
                  // Items
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      pw.Divider(color: colorBorder, height: 1, thickness: 0.5),
                    pw.Container(
                      color: i % 2 == 1 ? const PdfColor.fromInt(0xFFFAFAFA) : PdfColors.white,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              items[i].description,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: colorPrimary,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              items[i].quantity.toStringAsFixed(
                                items[i].quantity.truncateToDouble() == items[i].quantity ? 0 : 2,
                              ),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 9.5, color: colorPrimary),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              fmtMoney(items[i].unitPrice),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 9.5, color: colorPrimary),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              fmtMoney(items[i].lineTotal > 0
                                  ? items[i].lineTotal
                                  : items[i].quantity * items[i].unitPrice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: colorPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // TOTALS & BREAKDOWN
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Notes & Payment Confirmation
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: isPaid
                          ? const PdfColor.fromInt(0xFFF2FBF4)
                          : const PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(
                        color: isPaid ? colorSuccess : colorBorder,
                        width: 0.8,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isPaid ? 'PAYMENT STATUS: SETTLED' : 'PAYMENT NOTICE',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: isPaid ? colorSuccess : colorWarning,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          isPaid
                              ? 'Thank you! Payment for ${bill.billNumber} has been received in full. Keep this document for your insurance and medical expense records.'
                              : 'Please settle the balance due before ${fmtDate(bill.dueDate)} at the hospital billing desk or through the mobile patient portal instant payment option.',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: colorSecondary,
                          ),
                        ),
                        if (bill.notes != null && bill.notes!.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Note: ${bill.notes!}',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: colorSecondary,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                // Breakdown box
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: colorHeaderBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: colorBorder, width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal:', fmtMoney(bill.subtotal > 0 ? bill.subtotal : bill.total)),
                        if (bill.taxAmount > 0)
                          _buildTotalRow('Tax (${bill.taxPercent}%):', fmtMoney(bill.taxAmount)),
                        if (bill.discount > 0)
                          _buildTotalRow('Discount:', '- ${fmtMoney(bill.discount)}', isNegative: true),
                        pw.SizedBox(height: 4),
                        pw.Divider(color: colorBorder, thickness: 0.8),
                        pw.SizedBox(height: 4),
                        _buildTotalRow('Total Amount:', fmtMoney(bill.total), isBold: true, fontSize: 11),
                        _buildTotalRow('Amount Paid:', fmtMoney(bill.amountPaid), color: colorSuccess),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: bill.outstanding > 0
                                ? const PdfColor.fromInt(0xFFFFF1F2)
                                : const PdfColor.fromInt(0xFFF0FDF4),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                          ),
                          child: _buildTotalRow(
                            'Balance Due:',
                            fmtMoney(bill.outstanding),
                            isBold: true,
                            fontSize: 10.5,
                            color: bill.outstanding > 0 ? const PdfColor.fromInt(0xFFE11D48) : colorSuccess,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // SIGNATURE & FOOTER
            pw.Divider(color: colorBorder, thickness: 0.8),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Generated electronically by MyClinics Patient Portal.',
                      style: const pw.TextStyle(fontSize: 8, color: colorSecondary),
                    ),
                    pw.Text(
                      'No signature is required for electronic verified billing receipts.',
                      style: const pw.TextStyle(fontSize: 7.5, color: colorSecondary),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Authorized Signatory',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: colorPrimary,
                      ),
                    ),
                    pw.Text(
                      clinicTitle,
                      style: const pw.TextStyle(fontSize: 8, color: colorSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildMetaRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF6E6E73)),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1D1D1F),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildTotalRow(
  String label,
  String value, {
  bool isBold = false,
  double fontSize = 9,
  bool isNegative = false,
  PdfColor? color,
}) {
  final textColor = color ?? (isNegative ? const PdfColor.fromInt(0xFF059669) : const PdfColor.fromInt(0xFF1D1D1F));
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isBold ? const PdfColor.fromInt(0xFF1D1D1F) : const PdfColor.fromInt(0xFF6E6E73),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

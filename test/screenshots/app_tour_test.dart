// Renders every tab of the patient app with sample data and saves each one
// as a PNG, so a design change can be reviewed without a device.
//
//   flutter test test/screenshots --dart-define=SHOTS_DIR=build/screenshots
//
// Without SHOTS_DIR the test is skipped, so the normal suite never writes
// files.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/screens/patient_home_page.dart';
import 'package:my_patines/services/patient_portal_service.dart';
import 'package:my_patines/services/records_service.dart';
import 'package:my_patines/widgets/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_portal_service.dart';
import '../support/fake_records_service.dart';

const _shotsDir = String.fromEnvironment('SHOTS_DIR');

const _session = PatientSession(
  clinicId: 'clc_demo',
  token: 'demo_token',
  patientId: 'PAT-2041',
  name: 'Meera Krishnan',
  email: 'meera@example.com',
  clinicName: 'Riverside Family Clinic',
);

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

FakePortalService _portal() {
  final today = DateTime.now();
  return FakePortalService(
    session: _session,
    patient: const PatientProfile(
      patientId: 'PAT-2041',
      fullName: 'Meera Krishnan',
      mobile: '9000000000',
      email: 'meera@example.com',
      gender: 'Female',
      dateOfBirth: '1991-04-12',
      bloodGroup: 'B+',
      city: 'Kochi',
      state: 'Kerala',
      height: '162',
      weight: '58',
      bloodPressure: '118/76',
      allergies: ['Penicillin'],
      emergencyContactName: 'Arjun Krishnan',
      emergencyContactRelationship: 'Spouse',
    ),
    clinic: const ClinicInfo(
      name: 'Riverside Family Clinic',
      phone: '0484 000 0000',
      email: 'care@riverside.example',
      city: 'Kochi',
      workingHoursOpen: '09:00',
      workingHoursClose: '19:00',
    ),
    appointments: [
      AppointmentEntry(
        appointmentId: 'apt_1',
        doctorName: 'Dr. Anita Rao',
        date: _ymd(today),
        time: '10:30',
        status: 'scheduled',
        tokenNumber: 7,
        department: 'General Medicine',
        reason: 'Follow-up on blood pressure',
      ),
      AppointmentEntry(
        appointmentId: 'apt_2',
        doctorName: 'Dr. Vikram Menon',
        date: _ymd(today.add(const Duration(days: 6))),
        time: '16:00',
        status: 'scheduled',
        tokenNumber: 3,
        department: 'Dermatology',
      ),
      AppointmentEntry(
        appointmentId: 'apt_3',
        doctorName: 'Dr. Anita Rao',
        date: _ymd(today.subtract(const Duration(days: 21))),
        time: '11:00',
        status: 'completed',
        tokenNumber: 12,
        department: 'General Medicine',
      ),
    ],
    prescriptions: const [
      PrescriptionEntry(
        prescriptionId: 'rx_1',
        visitDate: '2026-10-30',
        diagnosis: 'Mild hypertension',
        doctorName: 'Dr. Anita Rao',
        medicines: [
          MedicineEntry(
            name: 'Amlodipine 5mg',
            dosage: '1 tablet',
            frequency: 'Once daily',
            duration: '30 days',
          ),
        ],
      ),
    ],
    bills: [
      BillEntry(
        billId: 'bil_1',
        billNumber: 'INV-1042',
        items: const [
          BillItemEntry(
            description: 'Consultation',
            unitPrice: 600,
            lineTotal: 600,
          ),
          BillItemEntry(
            description: 'Lipid profile',
            unitPrice: 900,
            lineTotal: 900,
          ),
        ],
        subtotal: 1500,
        total: 1500,
        balanceDue: 900,
        amountPaid: 600,
        status: 'issued',
        paymentStatus: 'partial',
        doctorName: 'Dr. Anita Rao',
        invoiceDate: today.subtract(const Duration(days: 3)),
      ),
      BillEntry(
        billId: 'bil_2',
        billNumber: 'INV-0987',
        items: const [
          BillItemEntry(
            description: 'Consultation',
            unitPrice: 600,
            lineTotal: 600,
          ),
        ],
        subtotal: 600,
        total: 600,
        amountPaid: 600,
        status: 'paid',
        paymentStatus: 'paid',
        doctorName: 'Dr. Anita Rao',
        invoiceDate: today.subtract(const Duration(days: 21)),
        paidAt: today.subtract(const Duration(days: 21)),
      ),
    ],
    doctors: const [
      DoctorEntry(
        doctorId: 'doc_1',
        name: 'Dr. Anita Rao',
        specialization: 'General Physician',
        experienceYears: 14,
        fee: 600,
      ),
      DoctorEntry(
        doctorId: 'doc_2',
        name: 'Dr. Vikram Menon',
        specialization: 'Dermatologist',
        experienceYears: 9,
        fee: 800,
      ),
      DoctorEntry(
        doctorId: 'doc_3',
        name: 'Dr. Leela Thomas',
        specialization: 'Paediatrician',
        experienceYears: 11,
        fee: 700,
      ),
    ],
  );
}

FakeRecordsService _records() {
  final today = DateTime.now();
  return FakeRecordsService(
    session: _session,
    data: MedicalRecordsData(
      folders: const [
        MedicalRecordFolderEntry(folderId: 'f_lab', name: 'Lab reports'),
        MedicalRecordFolderEntry(folderId: 'f_scan', name: 'Scans'),
      ],
      files: [
        MedicalRecordFileEntry(
          fileId: 'file_1',
          fileName: 'Lipid profile.pdf',
          folder: 'Lab reports',
          mimeType: 'application/pdf',
          size: 284000,
          uploadedByName: 'Dr. Anita Rao',
          createdAt: today.subtract(const Duration(days: 3)),
        ),
        MedicalRecordFileEntry(
          fileId: 'file_2',
          fileName: 'Chest X-ray.jpg',
          folder: 'Scans',
          mimeType: 'image/jpeg',
          size: 1240000,
          uploadedByName: 'Riverside Imaging',
          createdAt: today.subtract(const Duration(days: 40)),
        ),
      ],
      records: [
        MedicineRecordEntry(
          recordId: 'rec_1',
          diagnosis: 'Mild hypertension',
          symptoms: 'Occasional headaches',
          treatment: 'Amlodipine 5mg, low-salt diet',
          doctorName: 'Dr. Anita Rao',
          visitDate: today.subtract(const Duration(days: 21)),
        ),
      ],
    ),
  );
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await _loadFont('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  await _loadFont('Roboto', [
    for (final w in ['Regular', 'Medium', 'Bold']) '$material/Roboto-$w.ttf',
  ]);
  await _loadFont('HankenGrotesk', [
    for (final w in ['Regular', 'Medium', 'SemiBold'])
      'assets/fonts/HankenGrotesk-$w.ttf',
  ]);
  await _loadFont('Newsreader', ['assets/fonts/Newsreader-Medium.ttf']);
}

void main() {
  const tabs = ['home', 'appointments', 'records', 'billing', 'profile'];
  const navLabels = ['Home', 'Appointments', 'Records', 'Billing', 'Profile'];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  testWidgets('capture every tab', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // flutter_test draws shadows as hard slabs by default; render them as a
    // phone would, and restore the flag before the test ends.
    debugDisableShadows = false;

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: PatientHomePage(
            session: _session,
            portalService: _portal(),
            recordsService: _records(),
          ),
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_shotsDir/$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await settle();
    for (var i = 0; i < tabs.length; i++) {
      if (i > 0) {
        await tester.tap(find.text(navLabels[i]).last);
        await settle();
      }
      await capture('${i + 1}-${tabs[i]}');
    }
    debugDisableShadows = true;
  }, skip: _shotsDir.isEmpty);
}

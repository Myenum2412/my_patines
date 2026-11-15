import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_patines/models/patient_session.dart';
import 'package:my_patines/services/records_service.dart';

const _session = PatientSession(
  clinicId: 'clinic_123',
  token: 'test-token',
  patientId: 'pat_456',
  name: 'Asha',
);

void main() {
  test('fetchAll parses files, folders and clinical records', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      final path = request.url.path;
      if (path.endsWith('/medical-record')) {
        return http.Response(
          jsonEncode({
            'files': [
              {
                'fileId': 'file_1',
                'fileName': 'Blood report.pdf',
                'folder': 'lab-reports',
                'mimeType': 'application/pdf',
                'size': 2048,
                'version': 2,
                'uploadedByName': 'Front Desk',
                'createdAt': '2026-11-10T09:30:00.000Z',
              },
            ],
            'total': 1,
          }),
          200,
        );
      }
      if (path.endsWith('/medical-record/folders')) {
        expect(request.url.queryParameters['patientId'], 'pat_456');
        return http.Response(
          jsonEncode({
            'folders': [
              {
                'folderId': 'folder_1',
                'name': 'Lab Reports',
                'isDefault': true,
                'defaultKey': 'lab-reports',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/me/records')) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'recordId': 'rec_1',
                'diagnosis': 'Viral fever',
                'symptoms': 'Fever, cough',
                'treatment': 'Rest and fluids',
                'doctorName': 'Meera',
                'visitDate': '2026-11-09',
                'attachments': [
                  {'name': 'prescription.pdf'},
                ],
              },
            ],
            'total': 1,
          }),
          200,
        );
      }
      return http.Response('{"error":"Not found"}', 404);
    });

    final service = RecordsService(session: _session, client: client);
    final data = await service.fetchAll();

    expect(data.files, hasLength(1));
    expect(data.files.single.fileName, 'Blood report.pdf');
    expect(data.files.single.size, 2048);
    expect(data.files.single.version, 2);
    expect(data.folders.single.name, 'Lab Reports');
    expect(data.records.single.diagnosis, 'Viral fever');
    expect(data.records.single.doctorName, 'Meera');
    expect(data.records.single.attachments, contains('prescription.pdf'));
    expect(data.isEmpty, isFalse);
    service.dispose();
  });

  test('expired session surfaces a 401 RecordsException', () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"Unauthorized"}', 401);
    });

    final service = RecordsService(session: _session, client: client);
    await expectLater(
      service.fetchAll(),
      throwsA(
        isA<RecordsException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('session has expired')),
      ),
    );
    service.dispose();
  });

  test('account without a patientId fails clearly', () async {
    const session = PatientSession(clinicId: 'clinic_123', token: 'token');
    final service = RecordsService(session: session);
    await expectLater(
      service.fetchAll(),
      throwsA(
        isA<RecordsException>().having(
          (e) => e.message,
          'message',
          contains('linked to a patient profile'),
        ),
      ),
    );
    service.dispose();
  });

  test('offline or network failure surfaces a RecordsException', () async {
    final client = MockClient((request) async {
      throw http.ClientException('Failed host lookup: api.myclinic.myenum.in');
    });

    final service = RecordsService(session: _session, client: client);
    await expectLater(service.fetchAll(), throwsA(isA<RecordsException>()));
    service.dispose();
  });
}

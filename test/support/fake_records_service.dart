import 'package:my_patines/services/records_service.dart';

class FakeRecordsService extends RecordsService {
  FakeRecordsService({
    required super.session,
    this.data = const MedicalRecordsData(
      files: [],
      folders: [],
      records: [],
    ),
    this.downloadUrlResult = 'https://example.com/file.pdf',
  });

  MedicalRecordsData data;
  String downloadUrlResult;

  @override
  Future<MedicalRecordsData> fetchAll() async => data;

  @override
  Future<String> downloadUrl(String fileId) async => downloadUrlResult;
}

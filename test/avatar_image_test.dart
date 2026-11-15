import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_patines/models/patient_avatar.dart';
import 'package:my_patines/services/avatar_service.dart';
import 'package:my_patines/widgets/avatar_picker_sheet.dart';
import 'package:my_patines/widgets/patient_avatar_view.dart';

void main() {
  group('PatientAvatar Model Tests', () {
    test('Default avatar is doctor asset', () {
      const def = PatientAvatar.defaultAvatar;
      expect(def.type, AvatarType.asset);
      expect(def.assetPath, contains('avatar_doc_m.png'));
    });

    test('Serializes and deserializes correctly', () {
      final avatar = PatientAvatar(
        type: AvatarType.asset,
        assetPath: 'assets/images/avatars/avatar_female_1.png',
        gradientIndex: 2,
      );
      final json = avatar.toJson();
      final revived = PatientAvatar.fromJson(json);

      expect(revived.type, AvatarType.asset);
      expect(revived.assetPath, 'assets/images/avatars/avatar_female_1.png');
      expect(revived.gradientIndex, 2);
    });

    test('Migrates legacy types gracefully to asset', () {
      final legacy = {
        'type': 'customUrl',
        'customUrl': 'https://example.com/photo.jpg',
        'gradientIndex': 1,
      };
      final revived = PatientAvatar.fromJson(legacy);
      expect(revived.type, AvatarType.asset);
      expect(revived.assetPath, isNotNull);
    });
  });

  group('AvatarService Tests', () {
    test('Saves and retrieves avatar for patient', () async {
      const patientId = 'PAT-TEST-001';
      final avatar = PatientAvatar(
        type: AvatarType.asset,
        assetPath: 'assets/images/avatars/avatar_male_1.png',
        gradientIndex: 3,
      );

      await AvatarService.instance.saveAvatar(patientId, avatar);
      final retrieved = await AvatarService.instance.getAvatar(patientId);

      expect(retrieved.type, AvatarType.asset);
      expect(retrieved.assetPath, 'assets/images/avatars/avatar_male_1.png');
      expect(retrieved.gradientIndex, 3);
    });

    test('Notifier updates dynamically on avatar change', () async {
      const patientId = 'PAT-TEST-002';
      final notifier = AvatarService.instance.getNotifier(patientId);

      final newAvatar = PatientAvatar(
        type: AvatarType.monogram,
        gradientIndex: 4,
      );

      await AvatarService.instance.saveAvatar(patientId, newAvatar);
      expect(notifier.value.type, AvatarType.monogram);
      expect(notifier.value.gradientIndex, 4);
    });
  });

  group('PatientAvatarView Widget Tests', () {
    testWidgets('Renders monogram with user initials', (tester) async {
      const patientId = 'PAT-TEST-MONOGRAM';
      await AvatarService.instance.saveAvatar(
        patientId,
        const PatientAvatar(type: AvatarType.monogram, gradientIndex: 1),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PatientAvatarView(
                patientId: patientId,
                fullName: 'John Doe',
                size: 60,
              ),
            ),
          ),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
    });
  });

  group('AvatarPickerSheet Modal Tests', () {
    testWidgets('Modal displays image avatar tabs and NO URL field', (tester) async {
      const patientId = 'PAT-TEST-PICKER';
      await AvatarService.instance.saveAvatar(
        patientId,
        PatientAvatar.defaultAvatar,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAvatarPickerSheet(
                  context: context,
                  patientId: patientId,
                  fullName: 'Alice Smith',
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify modal header and tabs
      expect(find.text('Profile Avatar'), findsOneWidget);
      expect(find.text('Avatars'), findsOneWidget);
      expect(find.text('Camera / Photos'), findsOneWidget);
      expect(find.text('Monogram'), findsOneWidget);

      // Verify there are NO URL input fields
      expect(find.text('Photo URL'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // Verify categories in Avatars tab
      expect(find.text('Medical'), findsWidgets);
      expect(find.text('Save Avatar'), findsOneWidget);

      // Tap Save Avatar to close
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      expect(find.text('Profile Avatar'), findsNothing);
    });
  });
}

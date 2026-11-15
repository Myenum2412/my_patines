import 'package:flutter/material.dart';

enum AvatarType {
  asset, // Built-in illustrated avatar image asset
  file, // Device photo picked from gallery/camera
  monogram, // Stylized initials with chosen gradient
}

class PatientAvatar {
  const PatientAvatar({
    required this.type,
    this.assetPath,
    this.filePath,
    this.gradientIndex = 0,
  });

  final AvatarType type;
  final String? assetPath;
  final String? filePath;
  final int gradientIndex;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'assetPath': assetPath,
        'filePath': filePath,
        'gradientIndex': gradientIndex,
      };

  PatientAvatar copyWith({
    AvatarType? type,
    String? assetPath,
    String? filePath,
    int? gradientIndex,
  }) {
    return PatientAvatar(
      type: type ?? this.type,
      assetPath: assetPath ?? this.assetPath,
      filePath: filePath ?? this.filePath,
      gradientIndex: gradientIndex ?? this.gradientIndex,
    );
  }

  factory PatientAvatar.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'asset';
    final AvatarType type;
    if (typeName == 'file') {
      type = AvatarType.file;
    } else if (typeName == 'monogram') {
      type = AvatarType.monogram;
    } else {
      type = AvatarType.asset;
    }
    return PatientAvatar(
      type: type,
      assetPath: json['assetPath'] as String? ??
          (type == AvatarType.asset
              ? 'assets/images/avatars/avatar_doc_m.png'
              : null),
      filePath: json['filePath'] as String?,
      gradientIndex: (json['gradientIndex'] as num?)?.toInt() ?? 0,
    );
  }

  static const defaultAvatar = PatientAvatar(
    type: AvatarType.asset,
    assetPath: 'assets/images/avatars/avatar_doc_m.png',
    gradientIndex: 0,
  );
}

class AvatarTheme {
  static const List<({String path, String label, String category})> avatarAssets = [
    (path: 'assets/images/avatars/avatar_doc_m.png', label: 'Doctor (M)', category: 'Medical'),
    (path: 'assets/images/avatars/avatar_doc_f.png', label: 'Doctor (F)', category: 'Medical'),
    (path: 'assets/images/avatars/avatar_male_1.png', label: 'Young Man', category: 'General'),
    (path: 'assets/images/avatars/avatar_female_1.png', label: 'Young Woman', category: 'General'),
    (path: 'assets/images/avatars/avatar_male_2.png', label: 'Gentleman', category: 'Professional'),
    (path: 'assets/images/avatars/avatar_female_2.png', label: 'Professional', category: 'Professional'),
    (path: 'assets/images/avatars/avatar_senior_m.png', label: 'Senior (M)', category: 'Senior'),
    (path: 'assets/images/avatars/avatar_senior_f.png', label: 'Senior (F)', category: 'Senior'),
    (path: 'assets/images/avatars/avatar_kid_m.png', label: 'Boy', category: 'Pediatric'),
    (path: 'assets/images/avatars/avatar_kid_f.png', label: 'Girl', category: 'Pediatric'),
    (path: 'assets/images/avatars/avatar_wellness_m.png', label: 'Fitness (M)', category: 'Wellness'),
    (path: 'assets/images/avatars/avatar_wellness_f.png', label: 'Fitness (F)', category: 'Wellness'),
  ];

  static const List<List<Color>> gradients = [
    [Color(0xFF0071E3), Color(0xFF4394FF)], // Apple Blue
    [Color(0xFF059669), Color(0xFF34D399)], // Emerald Mint
    [Color(0xFF7C3AED), Color(0xFFA78BFA)], // Purple Violet
    [Color(0xFFDB2777), Color(0xFFF472B6)], // Rose Pink
    [Color(0xFFD97706), Color(0xFFFBBF24)], // Amber Gold
    [Color(0xFFDC2626), Color(0xFFF87171)], // Crimson Coral
    [Color(0xFF0891B2), Color(0xFF22D3EE)], // Cyan Teal
    [Color(0xFF1E293B), Color(0xFF475569)], // Slate Charcoal
  ];
}

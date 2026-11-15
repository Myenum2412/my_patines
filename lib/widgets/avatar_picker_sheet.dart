import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/patient_avatar.dart';
import '../services/avatar_service.dart';
import '../utils/formatters.dart';
import 'apple_ui.dart';

Future<void> showAvatarPickerSheet({
  required BuildContext context,
  required String patientId,
  required String fullName,
  VoidCallback? onUpdated,
}) async {
  final current = AvatarService.instance.getAvatarSync(patientId);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => _AvatarPickerModal(
      patientId: patientId,
      fullName: fullName,
      initialAvatar: current,
      onUpdated: onUpdated,
    ),
  );
}

class _AvatarPickerModal extends StatefulWidget {
  const _AvatarPickerModal({
    required this.patientId,
    required this.fullName,
    required this.initialAvatar,
    this.onUpdated,
  });

  final String patientId;
  final String fullName;
  final PatientAvatar initialAvatar;
  final VoidCallback? onUpdated;

  @override
  State<_AvatarPickerModal> createState() => _AvatarPickerModalState();
}

class _AvatarPickerModalState extends State<_AvatarPickerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AvatarType _selectedType;
  late int _selectedGradient;
  String _selectedAssetPath = AvatarTheme.avatarAssets.first.path;
  String? _pickedFilePath;
  Uint8List? _pickedImageBytes;
  String _selectedCategory = 'All';
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialAvatar.type;
    _selectedGradient = widget.initialAvatar.gradientIndex;

    if (widget.initialAvatar.assetPath != null &&
        widget.initialAvatar.assetPath!.isNotEmpty) {
      _selectedAssetPath = widget.initialAvatar.assetPath!;
    }
    _pickedFilePath = widget.initialAvatar.filePath;

    final initialTab = switch (_selectedType) {
      AvatarType.asset => 0,
      AvatarType.file => 1,
      AvatarType.monogram => 2,
    };
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PatientAvatar get _currentSelection {
    return switch (_selectedType) {
      AvatarType.asset => PatientAvatar(
          type: AvatarType.asset,
          assetPath: _selectedAssetPath,
          gradientIndex: _selectedGradient,
        ),
      AvatarType.file => PatientAvatar(
          type: AvatarType.file,
          filePath: _pickedFilePath,
          gradientIndex: _selectedGradient,
        ),
      AvatarType.monogram => PatientAvatar(
          type: AvatarType.monogram,
          gradientIndex: _selectedGradient,
        ),
    };
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedType = AvatarType.file;
        _pickedFilePath = picked.path;
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open image: $e'),
          backgroundColor: AppleColors.red,
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      if (_selectedType == AvatarType.file &&
          (_pickedImageBytes != null || _pickedFilePath != null)) {
        await AvatarService.instance.savePickedFile(
          widget.patientId,
          path: _pickedFilePath ?? 'avatar.jpg',
          bytes: _pickedImageBytes,
        );
      } else {
        await AvatarService.instance.saveAvatar(
          widget.patientId,
          _currentSelection,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile avatar updated successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save avatar: $e'),
          backgroundColor: AppleColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AvatarTheme.gradients[
        _selectedGradient.clamp(0, AvatarTheme.gradients.length - 1)];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Avatar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppleColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choose an illustrated avatar, photo, or monogram',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppleColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Live Preview Avatar
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                alignment: Alignment.center,
                child: _buildLivePreview(gradient),
              ),
            ),
            const SizedBox(height: 14),
            // Tab Selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: (index) {
                  setState(() {
                    _selectedType = switch (index) {
                      0 => AvatarType.asset,
                      1 => AvatarType.file,
                      2 => AvatarType.monogram,
                      _ => AvatarType.asset,
                    };
                  });
                },
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppleColors.blue,
                unselectedLabelColor: AppleColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Avatars'),
                  Tab(text: 'Camera / Photos'),
                  Tab(text: 'Monogram'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAssetGalleryTab(),
                  _buildDevicePhotoTab(),
                  _buildMonogramTab(),
                ],
              ),
            ),
            // Bottom Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppleColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Avatar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview(List<Color> gradient) {
    if (_selectedType == AvatarType.asset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Image.asset(
          _selectedAssetPath,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _previewInitials(),
        ),
      );
    }

    if (_selectedType == AvatarType.file) {
      if (_pickedImageBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Image.memory(
            _pickedImageBytes!,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _previewInitials(),
          ),
        );
      }
      if (_pickedFilePath != null && _pickedFilePath!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Image.file(
            File(_pickedFilePath!),
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _previewInitials(),
          ),
        );
      }
      return const Icon(
        Icons.add_a_photo_rounded,
        size: 36,
        color: Colors.white,
      );
    }

    return _previewInitials();
  }

  Widget _previewInitials() {
    return Text(
      initialsOf(widget.fullName),
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAssetGalleryTab() {
    final categories = [
      'All',
      'Medical',
      'General',
      'Professional',
      'Senior',
      'Pediatric',
      'Wellness',
    ];

    final filteredAssets = _selectedCategory == 'All'
        ? AvatarTheme.avatarAssets
        : AvatarTheme.avatarAssets
            .where((a) => a.category == _selectedCategory)
            .toList();

    return Column(
      children: [
        // Category Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final isSel = _selectedCategory == cat;
              return AppleTapBounce(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? AppleColors.blue : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                        color: isSel ? Colors.white : AppleColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Grid of Avatars
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: filteredAssets.length,
            itemBuilder: (context, i) {
              final item = filteredAssets[i];
              final isSelected = _selectedType == AvatarType.asset &&
                  _selectedAssetPath == item.path;

              return AppleTapBounce(
                onTap: () {
                  setState(() {
                    _selectedType = AvatarType.asset;
                    _selectedAssetPath = item.path;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppleColors.blueLight : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppleColors.blue
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          item.path,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? AppleColors.blue
                                : AppleColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected
                              ? AppleColors.blue.withValues(alpha: 0.8)
                              : AppleColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDevicePhotoTab() {
    final hasPhoto = _selectedType == AvatarType.file &&
        (_pickedImageBytes != null ||
            (_pickedFilePath != null && _pickedFilePath!.isNotEmpty));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        const Text(
          'Upload Your Photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppleColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select a real picture from your gallery or capture a new one with your device camera.',
          style: TextStyle(
            fontSize: 12,
            color: AppleColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: AppleTapBounce(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppleColors.blueLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppleColors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        size: 32,
                        color: AppleColors.blue,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Photo Gallery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.blue,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose from device',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppleColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppleTapBounce(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        size: 32,
                        color: AppleColors.textPrimary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Take Photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Use camera',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (hasPhoto) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppleColors.greenLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppleColors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _pickedImageBytes != null
                      ? Image.memory(
                          _pickedImageBytes!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(_pickedFilePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Selected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.green,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ready to save as your profile avatar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppleColors.red,
                    size: 20,
                  ),
                  tooltip: 'Clear photo',
                  onPressed: () {
                    setState(() {
                      _pickedImageBytes = null;
                      _pickedFilePath = null;
                      _selectedType = AvatarType.asset;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppleColors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Images are securely stored on your device and will be displayed in your profile header and home dashboard.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppleColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonogramTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        const Text(
          'Gradient Monogram',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppleColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Display your personalized initials cleanly styled over curated Apple gradient themes.',
          style: TextStyle(
            fontSize: 12,
            color: AppleColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < AvatarTheme.gradients.length; i++) ...[
              AppleTapBounce(
                onTap: () {
                  setState(() {
                    _selectedType = AvatarType.monogram;
                    _selectedGradient = i;
                  });
                },
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AvatarTheme.gradients[i],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _selectedType == AvatarType.monogram &&
                              _selectedGradient == i
                          ? Colors.black
                          : Colors.transparent,
                      width: 2.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AvatarTheme.gradients[i].first
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initialsOf(widget.fullName),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

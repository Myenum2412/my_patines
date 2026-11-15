import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient_avatar.dart';
import '../services/avatar_service.dart';
import '../utils/formatters.dart';
import 'apple_ui.dart';

class PatientAvatarView extends StatelessWidget {
  const PatientAvatarView({
    super.key,
    required this.patientId,
    required this.fullName,
    this.size = 56,
    this.showEditBadge = false,
    this.onTap,
  });

  final String patientId;
  final String fullName;
  final double size;
  final bool showEditBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final notifier = AvatarService.instance.getNotifier(patientId);

    Widget avatarContent(PatientAvatar avatar) {
      final gradient = AvatarTheme.gradients[
          avatar.gradientIndex.clamp(0, AvatarTheme.gradients.length - 1)];

      Widget inner;
      if (avatar.type == AvatarType.asset &&
          avatar.assetPath != null &&
          avatar.assetPath!.trim().isNotEmpty) {
        inner = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.32),
          child: Image.asset(
            avatar.assetPath!.trim(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(gradient),
          ),
        );
      } else if (avatar.type == AvatarType.file &&
          avatar.filePath != null &&
          avatar.filePath!.trim().isNotEmpty) {
        inner = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.32),
          child: Image.file(
            File(avatar.filePath!.trim()),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(gradient),
          ),
        );
      } else {
        inner = _buildFallback(gradient);
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: size * 0.22,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: inner,
      );
    }

    final avatarWidget = ValueListenableBuilder<PatientAvatar>(
      valueListenable: notifier,
      builder: (context, avatar, _) {
        if (!showEditBadge) {
          return avatarContent(avatar);
        }

        final badgeSize = (size * 0.34).clamp(18.0, 26.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            avatarContent(avatar),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: AppleColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: badgeSize * 0.52,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (onTap != null) {
      return AppleTapBounce(
        onTap: onTap,
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }

  Widget _buildFallback(List<Color> gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(fullName),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

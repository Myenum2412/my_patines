import 'package:flutter/material.dart';
import 'apple_ui.dart';

import 'app_animations.dart';

/// A consistently styled, robust and responsive popup sheet or dialog used
/// for record, appointment, prescription and invoice details.
///
/// On wide displays (tablets/desktops/web, width >= 640px) it renders as a
/// centered modal dialog with a max-width of 560px. On mobile, it displays as
/// an elegant bottom sheet that auto-fits its content up to 88% of screen height
/// without gesture collisions or layout overflows.
Future<void> showDetailsSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required IconData icon,
  Color accent = AppleColors.brand,
  required List<Widget> children,
  Widget? footer,
}) {
  final mediaQuery = MediaQuery.of(context);
  final revealedChildren = <Widget>[
    for (final (index, child) in children.indexed)
      FadeSlideIn(
        // The sheet's rows settle together as one block, never one by one.
        delay: Duration(milliseconds: index == 0 ? 60 : 120),
        offset: const Offset(0, 8),
        child: child,
      ),
  ];
  final isWide = mediaQuery.size.width >= 640;

  if (isWide) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x730F172A),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: mediaQuery.size.height * 0.88,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x260F172A),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    onClose: () => Navigator.of(dialogContext).pop(),
                    showDragHandle: false,
                  ),
                  const Divider(height: 1, color: AppleColors.border),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: revealedChildren,
                      ),
                    ),
                  ),
                  if (footer != null) ...[
                    const Divider(height: 1, color: AppleColors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                      child: footer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A0F172A),
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              accent: accent,
              onClose: () => Navigator.of(sheetContext).pop(),
              showDragHandle: true,
            ),
            const Divider(height: 1, color: AppleColors.border),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: revealedChildren,
                ),
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1, color: AppleColors.border),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: footer,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.accent,
    required this.onClose,
    required this.showDragHandle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onClose;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppleColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, showDragHandle ? 10 : 16, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppleColors.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppleColors.textSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: AppleColors.canvas,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppleColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    this.icon,
    this.accent = AppleColors.brand,
    required this.children,
  });

  final String title;
  final IconData? icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 7),
              ],
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: AppleColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.accent = AppleColors.brand,
  });

  final String title;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 7),
          ],
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: AppleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailField extends StatelessWidget {
  const DetailField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: Icon(icon, size: 15, color: AppleColors.textTertiary),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppleColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '—' : value.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppleColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label on the left and a value on the right, useful for totals.
class DetailAmountRow extends StatelessWidget {
  const DetailAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (emphasized ? AppleColors.textPrimary : AppleColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasized ? 14 : 13,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
                color: emphasized ? AppleColors.textPrimary : AppleColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 16 : 13.5,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

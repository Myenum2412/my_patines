import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Apple Design System colors, metrics, and micro-interaction widgets.
/// Inspired by iOS 17/18, Apple Health, Apple Wallet, and Apple ID aesthetics.
class AppleColors {
  AppleColors._();

  // Backgrounds
  static const canvas = Color(0xFFF5F5F7);
  static const groupedBackground = Color(0xFFF2F2F7);
  static const card = Colors.white;
  static const glassOverlay = Color(0xD8FFFFFF);
  static const darkGlassOverlay = Color(0xC01D1D1F);

  // Typography
  static const textPrimary = Color(0xFF1D1D1F);
  static const textSecondary = Color(0xFF86868B);
  static const textTertiary = Color(0xFFA1A1A6);

  // Apple Accents
  static const blue = Color(0xFF0071E3); // Apple System Blue
  static const blueLight = Color(0xFFE8F2FD);
  static const green = Color(0xFF34C759); // Apple Mint/Green
  static const greenLight = Color(0xFFE8F8EE);
  static const red = Color(0xFFFF3B30); // Apple Coral/Red
  static const redLight = Color(0xFFFFECEB);
  static const orange = Color(0xFFFF9500); // Apple Orange
  static const orangeLight = Color(0xFFFFF3E0);
  static const purple = Color(0xFF5856D6); // Apple Indigo
  static const purpleLight = Color(0xFFEFEBFA);
  static const pink = Color(0xFFFF2D55); // Apple Health Rose
  static const pinkLight = Color(0xFFFFEBF0);
  static const teal = Color(0xFF30B0C7);
  static const tealLight = Color(0xFFE6F7FA);

  // Borders & Dividers
  static const border = Color(0xFFE5E5EA);
  static const hairline = Color(0xFFEEEEF2);
  static const separator = Color(0xFFE5E5EA);

  // Soft Layered Apple Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 18,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 28,
      offset: Offset(0, 12),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      offset: Offset(0, 3),
      spreadRadius: 0,
    ),
  ];
}

/// Tactile bounce micro-interaction that scales down on press and springs back on release.
class AppleTapBounce extends StatefulWidget {
  const AppleTapBounce({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.shrinkScale = 0.965,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double shrinkScale;
  final HitTestBehavior behavior;

  @override
  State<AppleTapBounce> createState() => _AppleTapBounceState();
}

class _AppleTapBounceState extends State<AppleTapBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 170),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.shrinkScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.enabled && widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.enabled && widget.onTap != null) {
      _controller.reverse();
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.enabled && widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onTap == null) {
      return widget.child;
    }
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Continuous squircle card with Apple border, soft layered shadow, and optional press bounce.
class AppleCard extends StatelessWidget {
  const AppleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.backgroundColor = Colors.white,
    this.border,
    this.shadow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: shadow ?? AppleColors.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return AppleTapBounce(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Frosted glass background container with subtle backdrop blur and hairline border.
class AppleGlassContainer extends StatelessWidget {
  const AppleGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.blur = 18,
    this.overlayColor = AppleColors.glassOverlay,
    this.borderColor = AppleColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final Color overlayColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: overlayColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Apple-style sliding pill segmented control.
class AppleSegmentedControl<T> extends StatelessWidget {
  const AppleSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBF0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: AppleTapBounce(
              onTap: () => onChanged(entry.key),
              shrinkScale: 0.98,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppleColors.textPrimary
                        : AppleColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Apple-style primary filled action button with spring tactile feedback.
class AppleButton extends StatelessWidget {
  const AppleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppleColors.blue,
    this.foregroundColor = Colors.white,
    this.isLoading = false,
    this.height = 50,
    this.borderRadius = 14,
    this.elevation = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final bool elevation;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return AppleTapBounce(
      enabled: !isDisabled,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          color: isDisabled
              ? backgroundColor.withValues(alpha: 0.5)
              : backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: elevation && !isDisabled
              ? [
                  BoxShadow(
                    color: backgroundColor.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foregroundColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Grouped inset card (iOS Settings style) that automatically nests rows with hairlines.
class AppleInsetGroup extends StatelessWidget {
  const AppleInsetGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              header!.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppleColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppleColors.border, width: 0.8),
            boxShadow: AppleColors.cardShadow,
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.8,
                    indent: 16,
                    color: AppleColors.hairline,
                  ),
              ],
            ],
          ),
        ),
        if (footer != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              footer!,
              style: const TextStyle(
                fontSize: 12,
                color: AppleColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

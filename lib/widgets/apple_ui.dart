import 'dart:ui';
import 'package:flutter/material.dart';

import 'app_animations.dart';

/// The app's one colour system, "MyClinic blue", taken from the logo: a cool
/// paper-white ground, deep navy ink, the logo's bright blue for every action,
/// and its navy as the deep end of the one brand gradient.
///
/// The class keeps its historical name so every screen reads from it.
class AppleColors {
  AppleColors._();

  // Grounds
  static const canvas = Color(0xFFF3F7FC);
  static const groupedBackground = Color(0xFFE8EFF8);
  static const card = Colors.white;
  static const ink = Color(0xFF0B1B33);
  static const glassOverlay = Color(0xF2FFFFFF);
  static const darkGlassOverlay = Color(0xE60B1B33);

  // Text
  static const textPrimary = Color(0xFF0B1B33);
  static const textSecondary = Color(0xFF4E5D73);
  static const textTertiary = Color(0xFF8794A8);

  // Brand: every primary action, selection and link. Sampled from the logo.
  static const brand = Color(0xFF0A6BE0);
  static const brandBright = Color(0xFF0A84F0);
  static const brandDeep = Color(0xFF0A3E9A);
  static const brandSky = Color(0xFF8CC3F7);
  static const brandLight = Color(0xFFE5F0FD);

  /// The brand tone that reads on [brand] itself and on dark grounds.
  static const brandOnDark = Color(0xFFCFE4FC);

  /// The logo's own sweep, bright blue to navy: used once per screen at most.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBright, brand, brandDeep],
    stops: [0, 0.45, 1],
  );

  // Status tints
  static const green = Color(0xFF12805C);
  static const greenLight = Color(0xFFE1F4EC);
  static const red = Color(0xFFCC3B55);
  static const redLight = Color(0xFFFCE7EB);
  static const orange = Color(0xFFB36A00);
  static const orangeLight = Color(0xFFFFF0D9);
  // Kept under its old name; now a navy-indigo from the logo's deep end.
  static const purple = Color(0xFF2F52B8);
  static const purpleLight = Color(0xFFE6ECFA);
  static const pink = Color(0xFFC03D78);
  static const pinkLight = Color(0xFFFBE6EF);
  static const teal = Color(0xFF0B8585);
  static const tealLight = Color(0xFFDDF3F2);

  // Lines
  static const border = Color(0xFFDCE5F0);
  static const hairline = Color(0xFFE6EDF6);
  static const separator = Color(0xFFDCE5F0);

  /// Cards lift off the ground on a faint navy shadow.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F0A3E9A), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Things that float above the page (sheets, the nav bar, the book
  /// button) cast a deeper, still soft shadow.
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x1F0A3E9A), blurRadius: 30, offset: Offset(0, 10)),
  ];

  /// The glow under anything painted in [brandGradient].
  static const List<BoxShadow> brandShadow = [
    BoxShadow(color: Color(0x400A6BE0), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

/// Corner radii, so every surface curves the same way.
abstract final class AppRadius {
  static const double card = 24;
  static const double inner = 16;
  static const double button = 999;
  static const double chip = 999;
}

/// One rounded geometric sans, Hanken Grotesk, to match the logo's
/// letterforms: SemiBold with tight tracking for headings and figures,
/// Regular and Medium for everything else.
abstract final class AppType {
  static const family = 'HankenGrotesk';

  /// The face for headings and figures (the same family, set heavier).
  static const displayFamily = family;

  static const display = TextStyle(
    fontFamily: displayFamily,
    fontSize: 36,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.1,
    color: AppleColors.textPrimary,
  );
  static const title = TextStyle(
    fontFamily: displayFamily,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppleColors.textPrimary,
  );
  static const heading = TextStyle(
    fontFamily: displayFamily,
    fontSize: 19,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
    color: AppleColors.textPrimary,
  );
  static const stat = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    color: AppleColors.textPrimary,
  );
  static const lead = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppleColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14.5,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppleColors.textSecondary,
  );
  static const button = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppleColors.textPrimary,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppleColors.textSecondary,
  );
  static const small = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppleColors.textSecondary,
  );
}

/// A white surface with a hairline edge and a faint lift: the app's one card.
class AppleSurface extends StatelessWidget {
  const AppleSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppleColors.hairline),
        boxShadow: AppleColors.cardShadow,
      ),
      child: child,
    );
  }
}

/// Press feedback: the target sinks 1px and scales to [shrinkScale] in 90ms,
/// then eases back in 120ms. No spring, no overshoot.
class AppleTapBounce extends StatefulWidget {
  const AppleTapBounce({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.shrinkScale = 0.985,
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
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Motion.press,
      reverseDuration: Motion.release,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Motion.ease,
      reverseCurve: Motion.ease,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.enabled && widget.onTap != null && !reduceMotionOf(context)) {
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
        animation: _progress,
        builder: (context, child) {
          final t = _progress.value;
          return Transform.translate(
            offset: Offset(0, t),
            child: Transform.scale(
              scale: 1 - (1 - widget.shrinkScale) * t,
              child: child,
            ),
          );
        },
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
    this.borderRadius = AppRadius.card,
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
      return AppleTapBounce(onTap: onTap, child: cardContent);
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
        color: AppleColors.groupedBackground,
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    this.backgroundColor = AppleColors.brand,
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
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

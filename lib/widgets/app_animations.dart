import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'apple_ui.dart';

/// One motion system for the whole app: every duration and curve lives here.
///
/// Quiet, fast UI steps; a single eased entrance for each screen's lead block;
/// no bounce or overshoot anywhere.
abstract final class Motion {
  // Durations.
  static const press = Duration(milliseconds: 90);
  static const hoverIn = Duration(milliseconds: 150);
  static const release = Duration(milliseconds: 120);
  static const panel = Duration(milliseconds: 200);
  static const slide = Duration(milliseconds: 240);
  static const settle = Duration(milliseconds: 520);
  static const enter = Duration(milliseconds: 700);
  static const image = Duration(milliseconds: 600);

  /// The one UI ease-out: every press, swap and state change.
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  /// Entrances: the lead block of a screen arriving once.
  static const Curve easeEnter = Cubic(0.22, 1, 0.36, 1);

  /// Travel only: an indicator moving from one place to another.
  static const Curve easeTravel = Cubic(0.65, 0, 0.35, 1);
}

/// Whether the user asked the OS to reduce motion.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slides [child] into place once, when it first appears.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.settle,
    this.offset = const Offset(0, 10),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Interval _interval;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    _interval = Interval(
      widget.delay.inMicroseconds / total.inMicroseconds,
      1,
      curve: Motion.easeEnter,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _reveal(
        _interval.transform(_controller.value),
        widget.offset,
        child!,
      ),
      child: widget.child,
    );
  }
}

/// Reveals one item of a screen from an animation owned by the parent.
///
/// Only the lead block (index 0) makes an entrance: it rises 12px. Every item
/// after it settles together as one block a beat later, so rows never cascade
/// one by one. Because the parent owns the progress, items rebuilt by a lazy
/// list while scrolling stay visible instead of playing their entrance again.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  static const _leadInterval = Interval(0, 0.7, curve: Motion.easeEnter);
  static const _restInterval = Interval(0.2, 0.85, curve: Motion.easeEnter);

  @override
  Widget build(BuildContext context) {
    final lead = index == 0;
    final interval = lead ? _leadInterval : _restInterval;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => _reveal(
        interval.transform(animation.value),
        lead ? const Offset(0, 12) : const Offset(0, 6),
        child!,
      ),
      child: child,
    );
  }
}

Widget _reveal(double progress, Offset offset, Widget child) {
  return Opacity(
    opacity: progress.clamp(0.0, 1.0),
    child: Transform.translate(offset: offset * (1 - progress), child: child),
  );
}

/// Soft fade used when the app swaps its root screen.
Route<T> fadeRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: Motion.settle,
    reverseTransitionDuration: Motion.slide,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.ease),
      child: child,
    ),
  );
}

/// Pushed pages rise slightly while fading in.
class FadeRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRisePageTransitionsBuilder();

  static final _rise = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).chain(CurveTween(curve: Motion.easeEnter));

  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => Motion.slide;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Motion.ease)),
      child: SlideTransition(position: animation.drive(_rise), child: child),
    );
  }
}

/// Owns the entrance progress for the [RevealItem]s below it, and plays it
/// again whenever [replayKey] changes (for example when a filter changes).
class RevealScope extends StatefulWidget {
  const RevealScope({super.key, required this.child, this.replayKey});

  final Widget child;
  final Object? replayKey;

  static Animation<double> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_RevealInherited>()
          ?.animation ??
      kAlwaysCompleteAnimation;

  @override
  State<RevealScope> createState() => _RevealScopeState();
}

class _RevealScopeState extends State<RevealScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _started = false;

  void _play() {
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(RevealScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) _play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _RevealInherited(animation: _controller, child: widget.child);
}

class _RevealInherited extends InheritedWidget {
  const _RevealInherited({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_RevealInherited oldWidget) =>
      animation != oldWidget.animation;
}

/// One list row that cascades in, driven by the nearest [RevealScope].
class RevealItem extends StatelessWidget {
  const RevealItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => StaggeredReveal(
    animation: RevealScope.of(context),
    index: index,
    child: child,
  );
}

/// Shimmering placeholder shown while a screen loads its data.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({super.key, this.rows = 4});

  final int rows;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotionOf(context)) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block({double? width, required double height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _block(width: 48, height: 48, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(height: 13),
                const SizedBox(height: 9),
                _block(width: 130, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final x = -2 + 4 * _controller.value;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(x - 1, -0.3),
                end: Alignment(x + 1, 0.3),
                colors: const [
                  AppleColors.border,
                  AppleColors.groupedBackground,
                  AppleColors.border,
                ],
              ).createShader(bounds),
              child: child,
            );
          },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _block(height: 132, radius: 22),
                const SizedBox(height: 22),
                for (var i = 0; i < widget.rows; i++) _row(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green circle that settles in while its tick draws itself.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 68});

  final double size;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Success',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              CustomPaint(painter: _SuccessCheckPainter(_controller.value)),
        ),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter(this.progress);

  final double progress;

  static const _green = AppleColors.green;
  static const _circle = Interval(0, 0.5, curve: Motion.easeEnter);
  static const _tick = Interval(0.35, 0.85, curve: Motion.ease);
  static const _burst = Interval(0.3, 1, curve: Curves.easeOut);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final burst = _burst.transform(progress);
    if (burst > 0 && burst < 1) {
      canvas.drawCircle(
        center,
        radius * (0.8 + 0.2 * burst),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - burst)
          ..color = _green.withValues(alpha: 0.5 * (1 - burst)),
      );
    }

    canvas.drawCircle(
      center,
      (radius * 0.86 * _circle.transform(progress)).clamp(0, radius),
      Paint()..color = AppleColors.greenLight,
    );

    final tick = _tick.transform(progress);
    if (tick <= 0) return;
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(s * 0.31, s * 0.52)
      ..lineTo(s * 0.45, s * 0.65)
      ..lineTo(s * 0.70, s * 0.37);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.075
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _green,
      );
    }
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Shakes [child] sideways on demand, used to signal a rejected action.
class ShakeOnError extends StatefulWidget {
  const ShakeOnError({super.key, required this.child});

  final Widget child;

  @override
  State<ShakeOnError> createState() => ShakeOnErrorState();
}

class ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  void shake() {
    if (!reduceMotionOf(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Transform.translate(
          offset: Offset(math.sin(t * math.pi * 6) * 9 * (1 - t), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Passes one soft band of light across [child] once, a beat after it
/// appears: the hero's entrance. It never repeats, and under reduced motion
/// it does not play at all.
class OneShotSheen extends StatefulWidget {
  const OneShotSheen({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.delay = const Duration(milliseconds: 380),
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Duration delay;

  @override
  State<OneShotSheen> createState() => _OneShotSheenState();
}

class _OneShotSheenState extends State<OneShotSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = Motion.easeTravel.transform(_controller.value);
                  if (t <= 0 || t >= 1) return const SizedBox.shrink();
                  final x = -1.6 + 3.2 * t;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x - 0.5, -1),
                        end: Alignment(x + 0.5, 1),
                        colors: const [
                          Color(0x00FFFFFF),
                          Color(0x2EFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

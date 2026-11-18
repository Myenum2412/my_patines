import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'apple_ui.dart';

/// Whether the user asked the OS to reduce motion.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slides [child] into place once, when it first appears.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 16),
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
      curve: Curves.easeOutCubic,
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

/// Reveals one item of a sequence from an animation owned by the parent.
///
/// Because the parent owns the progress, items rebuilt by a lazy list while
/// scrolling stay visible instead of playing their entrance again.
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

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 0.5);
    final interval = Interval(start, start + 0.5, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => _reveal(
        interval.transform(animation.value),
        const Offset(0, 18),
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
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Pushed pages rise slightly while fading in.
class FadeRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRisePageTransitionsBuilder();

  static final _rise = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
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
      context.dependOnInheritedWidgetOfExactType<_RevealInherited>()?.animation ??
      kAlwaysCompleteAnimation;

  @override
  State<RevealScope> createState() => _RevealScopeState();
}

class _RevealScopeState extends State<RevealScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
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
                  Color(0xFFE8E8ED),
                  Color(0xFFF7F7FA),
                  Color(0xFFE8E8ED),
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

/// A band of light that crosses [child] once, driven by [animation].
class ShineSweep extends StatelessWidget {
  const ShineSweep({
    super.key,
    required this.animation,
    required this.child,
    this.borderRadius = 24,
  });

  final Animation<double> animation;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = animation.value;
                  if (t <= 0 || t >= 1) return const SizedBox.shrink();
                  return FractionalTranslation(
                    translation: Offset(-1 + 2 * t, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-0.7, -1),
                          end: const Alignment(0.7, 1),
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.26),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
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

/// Sends a few soft rings out from a circular [child], then stops.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.child,
    this.color = AppleColors.blue,
    this.pulses = 3,
  });

  final Widget child;
  final Color color;
  final int pulses;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotionOf(context)) _controller.repeat(count: widget.pulses);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (!_controller.isAnimating) return const SizedBox.shrink();
                final t = Curves.easeOutCubic.transform(_controller.value);
                return Transform.scale(
                  scale: 1 + 0.7 * t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2,
                        color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Green circle that pops in while its tick draws itself.
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
          builder: (context, _) => CustomPaint(
            painter: _SuccessCheckPainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter(this.progress);

  final double progress;

  static const _green = AppleColors.green;
  static const _circle = Interval(0, 0.5, curve: Curves.easeOutBack);
  static const _tick = Interval(0.35, 0.85, curve: Curves.easeOutCubic);
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

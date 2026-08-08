// lib/widgets/animations/success_check_animation.dart
//
// A self-contained animated success checkmark: a green circle scales in
// with a slight overshoot, then the check is drawn with a stroke
// animation. Used wherever a screen wants to say "done" — deposit
// submitted, withdrawal requested, KYC uploaded, plan started, etc.
// Purely visual; place it above/around the existing success copy.
import 'package:flutter/material.dart';

class SuccessCheckAnimation extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onCompleted;

  const SuccessCheckAnimation({
    super.key,
    this.size = 88,
    this.color = const Color(0xFF4CAF7D),
    this.onCompleted,
  });

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _circleScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
  );
  late final Animation<double> _checkProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() => widget.onCompleted?.call());
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
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.scale(
            scale: _circleScale.value,
            child: CustomPaint(
              painter: _SuccessPainter(
                color: widget.color,
                checkProgress: _checkProgress.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuccessPainter extends CustomPainter {
  final Color color;
  final double checkProgress;
  _SuccessPainter({required this.color, required this.checkProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth / 2, ringPaint);

    if (checkProgress <= 0) return;

    // Checkmark drawn as two segments: short down-stroke then long
    // up-stroke, animated as one continuous path using pathMetrics so
    // it looks hand-drawn rather than faded in.
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.36);

    final metrics = path.computeMetrics().first;
    final extractPath =
        metrics.extractPath(0, metrics.length * checkProgress.clamp(0, 1));

    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extractPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) =>
      oldDelegate.checkProgress != checkProgress || oldDelegate.color != color;
}
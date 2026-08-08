import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium "Refer & Earn" illustration — two figures exchanging a glowing
/// infinity loop on a floating glass platform, surrounded by gift boxes
/// and coin stacks. Matches the mint / sage palette used across the
/// onboarding flow.
class ReferralIllustrationPainter extends CustomPainter {
  final double animValue; // 0..1 gentle float/pulse driver

  const ReferralIllustrationPainter({required this.animValue});

  static const Color _cream      = Color(0xFFF6EFE3);
  static const Color _creamDeep  = Color(0xFFEFE4CF);
  static const Color _sage       = Color(0xFF4CAF7D);
  static const Color _sageLight  = Color(0xFF7DCB9E);
  static const Color _sageDeep   = Color(0xFF2D7A52);
  static const Color _gold       = Color(0xFFD8B978);
  static const Color _goldLight  = Color(0xFFEDD9A6);
  static const Color _skinA      = Color(0xFFEFC9A6);
  static const Color _skinB      = Color(0xFFF3D9BE);
  static const Color _clothA     = Color(0xFFCBEBD6);
  static const Color _clothB     = Color(0xFFE7D9C4);
  static const Color _hair       = Color(0xFF3E2B22);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final floatY = math.sin(animValue * math.pi * 2) * h * 0.008;

    _drawBackdropGlow(canvas, size);
    _drawPlatform(canvas, size);
    _drawCoinStack(canvas, Offset(w * 0.16, h * 0.62), w * 0.16);
    _drawCoinStack(canvas, Offset(w * 0.86, h * 0.60), w * 0.14);
    _drawGiftBox(canvas, Offset(w * 0.18, h * 0.30 + floatY), w * 0.16, _clothB, _gold);
    _drawGiftBox(canvas, Offset(w * 0.36, h * 0.18 + floatY), w * 0.14, _clothA, _sageLight);
    _drawGiftBox(canvas, Offset(w * 0.83, h * 0.32 - floatY), w * 0.15, _clothA, _sageLight);
    _drawLoop(canvas, Offset(cx, h * 0.46), w * 0.30, h * 0.10);
    _drawFigure(canvas, Offset(w * 0.40, h * 0.50), w * 0.20, facingRight: true, cloth: _clothA, skin: _skinA);
    _drawFigure(canvas, Offset(w * 0.62, h * 0.42), w * 0.20, facingRight: false, cloth: _clothB, skin: _skinB);
  }

  void _drawBackdropGlow(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [_sageLight.withOpacity(0.16), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.42),
          radius: size.width * 0.65));
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.42), size.width * 0.65, glow);
  }

  void _drawPlatform(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.80), width: w * 0.82, height: h * 0.14);

    final shadow = Paint()
      ..color = _sageDeep.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.90), width: w * 0.7, height: h * 0.06),
        shadow);

    final platformPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.9), _cream.withOpacity(0.85)],
      ).createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.10));
    canvas.drawRRect(rrect, platformPaint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _creamDeep.withOpacity(0.7),
    );
  }

  void _drawCoinStack(Canvas canvas, Offset base, double r) {
    final coinCount = 4;
    for (int i = 0; i < coinCount; i++) {
      final cy = base.dy - i * (r * 0.34);
      final rect = Rect.fromCenter(center: Offset(base.dx, cy), width: r, height: r * 0.42);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: i.isEven ? [_gold, _goldLight] : [_goldLight, _gold],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _sageDeep.withOpacity(0.12),
      );
    }
  }

  void _drawGiftBox(Canvas canvas, Offset center, double s, Color box, Color ribbon) {
    final rect = Rect.fromCenter(center: center, width: s, height: s * 0.82);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, box.withOpacity(0.9)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.8),
    );

    // ribbon cross
    final ribbonPaint = Paint()..color = ribbon.withOpacity(0.85);
    canvas.drawRect(
        Rect.fromCenter(center: center, width: s, height: s * 0.14), ribbonPaint);
    canvas.drawRect(
        Rect.fromCenter(center: center, width: s * 0.14, height: s * 0.82), ribbonPaint);

    // bow
    final bowPaint = Paint()..color = ribbon;
    final bowY = center.dy - s * 0.41;
    canvas.drawCircle(Offset(center.dx - s * 0.09, bowY), s * 0.08, bowPaint);
    canvas.drawCircle(Offset(center.dx + s * 0.09, bowY), s * 0.08, bowPaint);
  }

  void _drawLoop(Canvas canvas, Offset center, double rw, double rh) {
    final path = Path();
    path.addOval(Rect.fromCenter(
        center: Offset(center.dx - rw * 0.32, center.dy), width: rw, height: rh));
    final path2 = Path();
    path2.addOval(Rect.fromCenter(
        center: Offset(center.dx + rw * 0.32, center.dy), width: rw, height: rh));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = _sageLight.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path2, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [_sage, Colors.white, _sage])
          .createShader(Rect.fromCircle(center: center, radius: rw));
    canvas.drawPath(path, linePaint);
    canvas.drawPath(path2, linePaint);
  }

  void _drawFigure(Canvas canvas, Offset feet, double s,
      {required bool facingRight, required Color cloth, required Color skin}) {
    final dir = facingRight ? 1.0 : -1.0;

    // legs
    final legPaint = Paint()..color = const Color(0xFF4A4038);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(feet.dx - s * 0.10, feet.dy - s * 0.10),
            width: s * 0.16,
            height: s * 0.42),
        Radius.circular(s * 0.06),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(feet.dx + s * 0.10, feet.dy - s * 0.10),
            width: s * 0.16,
            height: s * 0.42),
        Radius.circular(s * 0.06),
      ),
      legPaint,
    );

    // torso
    final torsoCenter = Offset(feet.dx, feet.dy - s * 0.55);
    final torsoRect = Rect.fromCenter(center: torsoCenter, width: s * 0.46, height: s * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(s * 0.16)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, cloth],
        ).createShader(torsoRect),
    );

    // reaching arm toward centre
    final shoulder = Offset(torsoCenter.dx + dir * s * 0.18, torsoCenter.dy - s * 0.14);
    final hand = Offset(feet.dx + dir * s * 0.55, torsoCenter.dy - s * 0.22);
    final armPath = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(
          shoulder.dx + dir * s * 0.18, shoulder.dy - s * 0.02, hand.dx, hand.dy);
    canvas.drawPath(
      armPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.11
        ..strokeCap = StrokeCap.round
        ..color = cloth,
    );
    canvas.drawCircle(hand, s * 0.07, Paint()..color = skin);

    // other arm resting
    final restHand = Offset(torsoCenter.dx - dir * s * 0.22, torsoCenter.dy + s * 0.20);
    canvas.drawLine(
      Offset(torsoCenter.dx - dir * s * 0.16, torsoCenter.dy - s * 0.10),
      restHand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.10
        ..strokeCap = StrokeCap.round
        ..color = cloth,
    );

    // head
    final headCenter = Offset(torsoCenter.dx, torsoCenter.dy - s * 0.36);
    canvas.drawCircle(headCenter, s * 0.15, Paint()..color = skin);
    // hair
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: s * 0.16), math.pi, math.pi);
    canvas.drawPath(hairPath, Paint()..color = _hair);
  }

  @override
  bool shouldRepaint(covariant ReferralIllustrationPainter old) =>
      old.animValue != animValue;
}
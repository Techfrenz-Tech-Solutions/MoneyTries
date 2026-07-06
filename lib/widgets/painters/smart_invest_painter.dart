import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium "Smart Investments" illustration:
/// Luxury dark candlestick/bar chart with a gold rising trend line,
/// floating AI orb, and subtle grid lines on a dark canvas.
class SmartInvestPainter extends CustomPainter {
  final double animValue;
  const SmartInvestPainter({required this.animValue});

  static const Color _gold       = Color(0xFFD4A843);
  static const Color _goldLight  = Color(0xFFEDC870);
  static const Color _goldDim    = Color(0xFF8B6914);
  static const Color _emerald    = Color(0xFF00C896);
  static const Color _emeraldDim = Color(0xFF00785A);
  static const Color _bgDeep     = Color(0xFF080E14);
  static const Color _surface    = Color(0xFF111E2C);
  static const Color _grid       = Color(0xFF1A2E42);
  static const Color _textMuted  = Color(0xFF3A5470);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawGrid(canvas, size, cx, cy);
    _drawBars(canvas, size, cx, cy);
    _drawTrendLine(canvas, size, cx, cy);
    _drawAIOrb(canvas, size, cx, cy);
    _drawLabels(canvas, size, cx, cy);
  }

  void _drawGrid(Canvas canvas, Size size, double cx, double cy) {
    final baseY = size.height * 0.80;
    final chartLeft = cx - size.width * 0.38;
    final chartRight = cx + size.width * 0.38;

    // Horizontal grid lines
    for (int i = 0; i < 4; i++) {
      final y = baseY - (i + 1) * size.height * 0.14;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        Paint()
          ..color = _grid
          ..strokeWidth = 0.8,
      );
    }
    // Base line
    canvas.drawLine(
      Offset(chartLeft, baseY),
      Offset(chartRight, baseY),
      Paint()..color = _goldDim.withOpacity(0.4)..strokeWidth = 1.0,
    );
  }

  void _drawBars(Canvas canvas, Size size, double cx, double cy) {
    final baseY = size.height * 0.80;
    final barCount = 6;
    final totalW = size.width * 0.72;
    final barW = totalW / barCount * 0.52;
    final spacing = totalW / barCount;
    final startX = cx - totalW / 2 + spacing * 0.24;
    final maxH = size.height * 0.5;
    final heights = [0.22, 0.36, 0.50, 0.64, 0.80, 0.95];
    final isGain = [false, true, true, false, true, true]; // alternating candle pattern

    for (int i = 0; i < barCount; i++) {
      final t = (animValue * 1.4 - i * 0.1).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final barH = maxH * heights[i] * t;
      final barX = startX + i * spacing;
      final barTop = baseY - barH;
      final gain = isGain[i];

      // Bar gradient
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gain
              ? [_emerald.withOpacity(0.9), _emeraldDim, const Color(0xFF003D2B)]
              : [_gold.withOpacity(0.9), _goldDim, const Color(0xFF3A1F00)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(barX, barTop, barW, barH));

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(barX, barTop, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rrect, barPaint);

      // Glass highlight
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barX + 1, barTop + 2, barW * 0.38, barH * 0.6),
          topLeft: const Radius.circular(5),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.0)],
          ).createShader(Rect.fromLTWH(barX, barTop, barW * 0.4, barH * 0.6)),
      );

      // Top rim glow
      canvas.drawLine(
        Offset(barX + 1, barTop + 0.8),
        Offset(barX + barW - 1, barTop + 0.8),
        Paint()
          ..color = (gain ? _emerald : _gold).withOpacity(0.6)
          ..strokeWidth = 1.2,
      );

      // Candle wick
      final wickX = barX + barW / 2;
      canvas.drawLine(
        Offset(wickX, barTop),
        Offset(wickX, barTop - barH * 0.12),
        Paint()
          ..color = (gain ? _emerald : _gold).withOpacity(0.55)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawTrendLine(Canvas canvas, Size size, double cx, double cy) {
    final baseY = size.height * 0.80;
    final barCount = 6;
    final totalW = size.width * 0.72;
    final barW = totalW / barCount * 0.52;
    final spacing = totalW / barCount;
    final startX = cx - totalW / 2 + spacing * 0.24;
    final maxH = size.height * 0.5;
    final heights = [0.22, 0.36, 0.50, 0.64, 0.80, 0.95];

    final t = animValue.clamp(0.0, 1.0);
    final path = Path();
    bool first = true;

    for (int i = 0; i < barCount; i++) {
      final progress = (t * barCount - i).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final barH = maxH * heights[i];
      final x = startX + i * spacing + barW / 2;
      final y = baseY - barH - 16;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Shadow glow
    canvas.drawPath(path, Paint()
      ..color = _gold.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Main line
    canvas.drawPath(path, Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // Dot nodes on trend
    for (int i = 0; i < barCount; i++) {
      final progress = (t * barCount - i).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final barH = maxH * heights[i];
      final x = startX + i * spacing + barW / 2;
      final y = baseY - barH - 16;

      canvas.drawCircle(Offset(x, y), 5.5,
          Paint()..color = _surface);
      canvas.drawCircle(Offset(x, y), 5.5,
          Paint()
            ..color = _gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
      canvas.drawCircle(Offset(x, y), 2.5,
          Paint()..color = _goldLight);
    }
  }

  void _drawAIOrb(Canvas canvas, Size size, double cx, double cy) {
    final orbX = cx + size.width * 0.28;
    final orbY = cy - size.height * 0.28;
    final pulse = math.sin(animValue * math.pi * 2) * 0.5 + 0.5;

    // Outer ring pulses
    for (int ring = 2; ring >= 0; ring--) {
      canvas.drawCircle(Offset(orbX, orbY), 18.0 + ring * 8 + pulse * 4,
          Paint()
            ..color = _gold.withOpacity(0.07 - ring * 0.02)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    // Orb body
    canvas.drawCircle(Offset(orbX, orbY), 18,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [_goldLight, _gold, _goldDim],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(orbX, orbY), radius: 18)));

    // Shine
    canvas.drawArc(
      Rect.fromCircle(center: Offset(orbX - 5, orbY - 5), radius: 10),
      -2.3, 1.0, false,
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // "AI" label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'AI',
        style: TextStyle(
          color: Color(0xFF080E14),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(orbX - tp.width / 2, orbY - tp.height / 2));
  }

  void _drawLabels(Canvas canvas, Size size, double cx, double cy) {
    final baseY = size.height * 0.80;
    const labels = ['+12%', '+18%', '+24%', '+31%', '+42%', '+58%'];
    final totalW = size.width * 0.72;
    final barW = totalW / 6 * 0.52;
    final spacing = totalW / 6;
    final startX = cx - totalW / 2 + spacing * 0.24;
    final maxH = size.height * 0.5;
    final heights = [0.22, 0.36, 0.50, 0.64, 0.80, 0.95];

    // Only draw label on last bar
    final i = 5;
    if (animValue > 0.85) {
      final barH = maxH * heights[i];
      final x = startX + i * spacing + barW / 2;
      final y = baseY - barH - 38;
      final opacity = ((animValue - 0.85) / 0.15).clamp(0.0, 1.0);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: _emerald.withOpacity(opacity),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
  }

  @override
  bool shouldRepaint(SmartInvestPainter old) => old.animValue != animValue;
}
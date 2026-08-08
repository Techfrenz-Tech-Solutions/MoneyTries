import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium "Grow Your Wealth" illustration:
/// A glowing golden seedling growing from a luxury vault/coin,
/// with floating gold coins and subtle particle ambiance.
class GrowWealthPainter extends CustomPainter {
  final double animValue;
  const GrowWealthPainter({required this.animValue});

  static const Color _gold = Color(0xFFD4A843);
  static const Color _goldLight = Color(0xFFEDC870);
  static const Color _goldDim = Color(0xFF8B6914);
  static const Color _emerald = Color(0xFF7DCB9E);
  static const Color _emeraldDim = Color(0xFF4CAF7D);
  static const Color _bgDeep = Color(
    0xFFF7F5F2,
  ); // warm beige-white (light theme)
  static const Color _surface = Color(0xFFEFF5F1); // soft mint-white

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawAmbientGlow(canvas, size, cx, cy);
    _drawCoin(canvas, size, cx, cy);
    _drawStem(canvas, size, cx, cy);
    _drawTree(canvas, size, cx, cy);
    _drawFloatingCoins(canvas, size, cx, cy);
    _drawParticles(canvas, size, cx, cy);
  }

  void _drawAmbientGlow(Canvas canvas, Size size, double cx, double cy) {
    // Bottom radial glow
    final glow = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomCenter,
        radius: 0.7,
        colors: [
          _gold.withOpacity(0.13),
          _emerald.withOpacity(0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
  }

  void _drawCoin(Canvas canvas, Size size, double cx, double cy) {
    final coinY = cy + size.height * 0.22;
    final r = size.width * 0.14;

    // Glow halo
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _gold.withOpacity(0.28 + animValue * 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, coinY), radius: r * 2.2),
          );
    canvas.drawCircle(Offset(cx, coinY), r * 2.2, halo);

    // Outer ring
    canvas.drawCircle(
      Offset(cx, coinY),
      r,
      Paint()..color = _goldDim.withOpacity(0.6),
    );

    // Coin face gradient
    final face = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: [_goldLight, _gold, _goldDim],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, coinY), radius: r));
    canvas.drawCircle(Offset(cx, coinY), r, face);

    // Shine arc
    final shine = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(cx - r * 0.2, coinY - r * 0.2),
        radius: r * 0.62,
      ),
      -2.4,
      1.1,
      false,
      shine,
    );

    // Dollar sign
    final tp = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: _bgDeep.withOpacity(0.85),
          fontSize: r * 1.0,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, coinY - tp.height / 2));

    // Rim border
    canvas.drawCircle(
      Offset(cx, coinY),
      r,
      Paint()
        ..color = _goldLight.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawStem(Canvas canvas, Size size, double cx, double cy) {
    final coinY = cy + size.height * 0.22;
    final stemBottom = coinY - size.width * 0.14;
    final stemTop = cy - size.height * 0.22;

    // Glowing stem
    final stemGlow = Paint()
      ..color = _emerald.withOpacity(0.25)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final stemLine = Paint()
      ..color = _emeraldDim
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(cx, stemBottom)
      ..cubicTo(
        cx - 10,
        stemBottom - (stemBottom - stemTop) * 0.35,
        cx + 8,
        stemBottom - (stemBottom - stemTop) * 0.65,
        cx,
        stemTop,
      );
    canvas.drawPath(stemPath, stemGlow);
    canvas.drawPath(stemPath, stemLine);
  }

  void _drawTree(Canvas canvas, Size size, double cx, double cy) {
    final stemTop = cy - size.height * 0.22;

    // Draw 3 tiers of triangular canopy (luxury topiary style)
    final tiers = [
      _TreeTier(y: stemTop + 8, w: 44, h: 36),
      _TreeTier(y: stemTop - 20, w: 56, h: 40),
      _TreeTier(y: stemTop - 52, w: 44, h: 34),
    ];

    for (int t = 0; t < tiers.length; t++) {
      final tier = tiers[t];
      final float = math.sin(animValue * math.pi * 2 + t * 0.8) * 2.5;
      final fy = tier.y + float;

      // Glow behind triangle
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [_emerald.withOpacity(0.18), Colors.transparent],
            ).createShader(
              Rect.fromCenter(
                center: Offset(cx, fy),
                width: tier.w * 2.2,
                height: tier.h * 2.2,
              ),
            );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, fy + tier.h * 0.25),
          width: tier.w * 1.8,
          height: tier.h * 1.3,
        ),
        glowPaint,
      );

      // Filled triangle
      final triPath = Path()
        ..moveTo(cx, fy - tier.h * 0.55)
        ..lineTo(cx + tier.w * 0.5, fy + tier.h * 0.45)
        ..lineTo(cx - tier.w * 0.5, fy + tier.h * 0.45)
        ..close();

      final triFill = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _emerald.withOpacity(0.95),
                _emeraldDim,
                const Color(0xFF004D38),
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(
              Rect.fromLTWH(
                cx - tier.w * 0.5,
                fy - tier.h * 0.55,
                tier.w,
                tier.h,
              ),
            );
      canvas.drawPath(triPath, triFill);

      // Highlight edge
      final edgePaint = Paint()
        ..color = _emerald.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(triPath, edgePaint);

      // Gold accent dots on tips
      canvas.drawCircle(
        Offset(cx, fy - tier.h * 0.55),
        4,
        Paint()
          ..shader = RadialGradient(colors: [_goldLight, _goldDim])
              .createShader(
                Rect.fromCircle(
                  center: Offset(cx, fy - tier.h * 0.55),
                  radius: 4,
                ),
              ),
      );
    }
  }

  void _drawFloatingCoins(Canvas canvas, Size size, double cx, double cy) {
    final coinConfigs = [
      _FloatCoin(
        dx: -size.width * 0.28,
        dy: -size.height * 0.25,
        r: 11,
        phase: 0.0,
        symbol: '\$',
      ),
      _FloatCoin(
        dx: size.width * 0.25,
        dy: -size.height * 0.18,
        r: 9,
        phase: 1.1,
        symbol: '€',
      ),
      _FloatCoin(
        dx: -size.width * 0.24,
        dy: size.height * 0.02,
        r: 10,
        phase: 2.1,
        symbol: '£',
      ),
      _FloatCoin(
        dx: size.width * 0.30,
        dy: size.height * 0.06,
        r: 8,
        phase: 0.6,
        symbol: '¥',
      ),
      _FloatCoin(
        dx: -size.width * 0.14,
        dy: -size.height * 0.35,
        r: 7,
        phase: 1.7,
        symbol: '\$',
      ),
      _FloatCoin(
        dx: size.width * 0.16,
        dy: -size.height * 0.34,
        r: 8,
        phase: 2.5,
        symbol: '₹',
      ),
    ];

    for (final c in coinConfigs) {
      final floatY = math.sin(animValue * math.pi * 2 + c.phase) * 5;
      final pos = Offset(cx + c.dx, cy + c.dy + floatY);

      // Shadow
      canvas.drawCircle(
        pos + const Offset(2, 3),
        c.r,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Coin
      canvas.drawCircle(
        pos,
        c.r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [_goldLight, _gold, _goldDim],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: pos, radius: c.r)),
      );

      // Border
      canvas.drawCircle(
        pos,
        c.r,
        Paint()
          ..color = _goldLight.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // Symbol
      final tp = TextPainter(
        text: TextSpan(
          text: c.symbol,
          style: TextStyle(
            color: _bgDeep.withOpacity(0.8),
            fontSize: c.r * 0.95,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawParticles(Canvas canvas, Size size, double cx, double cy) {
    final rng = math.Random(42);
    for (int i = 0; i < 22; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = 40 + rng.nextDouble() * size.width * 0.38;
      final offset = Offset(
        cx + math.cos(angle) * dist,
        cy + math.sin(angle) * dist,
      );
      final r = 1.0 + rng.nextDouble() * 2;
      final flicker = math.sin(animValue * math.pi * 2 + i * 0.7) * 0.5 + 0.5;
      canvas.drawCircle(
        offset,
        r,
        Paint()..color = _goldPrimary.withOpacity(0.08 + flicker * 0.14),
      );
    }
  }

  static const Color _goldPrimary = Color(0xFFD4A843);

  @override
  bool shouldRepaint(GrowWealthPainter old) => old.animValue != animValue;
}

class _TreeTier {
  final double y, w, h;
  const _TreeTier({required this.y, required this.w, required this.h});
}

class _FloatCoin {
  final double dx, dy, r, phase;
  final String symbol;
  const _FloatCoin({
    required this.dx,
    required this.dy,
    required this.r,
    required this.phase,
    required this.symbol,
  });
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium "Secure Your Earnings" illustration:
/// A gleaming dark vault door with gold accents, surrounded by shield
/// and subtle security rings on a deep dark background.
class SecureEarningsPainter extends CustomPainter {
  final double animValue;
  const SecureEarningsPainter({required this.animValue});

  static const Color _gold       = Color(0xFFD4A843);
  static const Color _goldLight  = Color(0xFFEDC870);
  static const Color _goldDim    = Color(0xFF8B6914);
  static const Color _emerald    = Color(0xFF00C896);
  static const Color _bgDeep     = Color(0xFF080E14);
  static const Color _surface    = Color(0xFF111E2C);
  static const Color _steel      = Color(0xFF2A3A4A);
  static const Color _steelLight = Color(0xFF3A5060);
  static const Color _steelDark  = Color(0xFF151E28);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawAmbientGlow(canvas, size, cx, cy);
    _drawShieldRings(canvas, size, cx, cy);
    _drawVaultBody(canvas, size, cx, cy);
    _drawVaultDoor(canvas, size, cx, cy);
    _drawLockIndicator(canvas, size, cx, cy);
    _drawGoldCoins(canvas, size, cx, cy);
    _drawSecurityDots(canvas, size, cx, cy);
  }

  void _drawAmbientGlow(Canvas canvas, Size size, double cx, double cy) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.65,
          colors: [
            _gold.withOpacity(0.07),
            _emerald.withOpacity(0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawShieldRings(Canvas canvas, Size size, double cx, double cy) {
    final vaultCy = cy - size.height * 0.04;
    final pulse = math.sin(animValue * math.pi * 2) * 0.5 + 0.5;

    // Dashed orbit rings
    for (int ring = 0; ring < 3; ring++) {
      final r = size.width * (0.32 + ring * 0.10);
      final ringOpacity = (0.12 - ring * 0.03) + pulse * 0.04;
      final dashPaint = Paint()
        ..color = _gold.withOpacity(ringOpacity)
        ..strokeWidth = ring == 0 ? 1.2 : 0.8
        ..style = PaintingStyle.stroke;

      _drawDashedCircle(canvas, Offset(cx, vaultCy), r, dashPaint, ring == 0 ? 24 : 18);
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius,
      Paint paint, int dashCount) {
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * math.pi * 2;
      final sweepAngle = (math.pi * 2 / dashCount) * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
    }
  }

  void _drawVaultBody(Canvas canvas, Size size, double cx, double cy) {
    final vaultW = size.width * 0.68;
    final vaultH = size.height * 0.58;
    final vaultX = cx - vaultW / 2;
    final vaultY = cy - vaultH * 0.52;

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(vaultX + 6, vaultY + 10, vaultW, vaultH),
          const Radius.circular(24)),
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Vault body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(vaultX, vaultY, vaultW, vaultH),
          const Radius.circular(24)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_steelLight, _steel, _steelDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(vaultX, vaultY, vaultW, vaultH)),
    );

    // Gold border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(vaultX, vaultY, vaultW, vaultH),
          const Radius.circular(24)),
      Paint()
        ..color = _gold.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Top shine
    canvas.drawRRect(
      RRect.fromRectAndCorners(
          Rect.fromLTWH(vaultX + 12, vaultY + 4, vaultW - 24, 6),
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12)),
      Paint()..color = Colors.white.withOpacity(0.1),
    );

    // Corner bolts
    final boltPositions = [
      Offset(vaultX + 22, vaultY + 22),
      Offset(vaultX + vaultW - 22, vaultY + 22),
      Offset(vaultX + 22, vaultY + vaultH - 22),
      Offset(vaultX + vaultW - 22, vaultY + vaultH - 22),
    ];
    for (final b in boltPositions) {
      canvas.drawCircle(b, 7, Paint()..color = _steelDark);
      canvas.drawCircle(b, 7,
          Paint()..color = _gold.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.drawCircle(b, 3.5, Paint()..color = _steelLight);
    }
  }

  void _drawVaultDoor(Canvas canvas, Size size, double cx, double cy) {
    final vaultH = size.height * 0.58;
    final doorCx = cx;
    final doorCy = cy - size.height * 0.52 + vaultH * 0.47;
    final doorR = size.width * 0.22;

    // Door shadow
    canvas.drawCircle(Offset(doorCx + 3, doorCy + 4), doorR,
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Door body
    canvas.drawCircle(Offset(doorCx, doorCy), doorR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.25, -0.35),
            colors: [_steelLight, _steel, _steelDark],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(
              center: Offset(doorCx, doorCy), radius: doorR)));

    // Outer ring
    canvas.drawCircle(Offset(doorCx, doorCy), doorR,
        Paint()
          ..color = _gold.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Inner gold ring
    canvas.drawCircle(Offset(doorCx, doorCy), doorR * 0.76,
        Paint()
          ..color = _goldDim.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Animated spokes
    const spokeCount = 8;
    final spokeAngleOffset = animValue * math.pi * 0.4;
    for (int i = 0; i < spokeCount; i++) {
      final angle = (i / spokeCount) * math.pi * 2 + spokeAngleOffset;
      canvas.drawLine(
        Offset(doorCx + doorR * 0.22 * math.cos(angle),
            doorCy + doorR * 0.22 * math.sin(angle)),
        Offset(doorCx + doorR * 0.7 * math.cos(angle),
            doorCy + doorR * 0.7 * math.sin(angle)),
        Paint()
          ..color = _gold.withOpacity(0.25)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Center knob
    canvas.drawCircle(Offset(doorCx, doorCy), doorR * 0.18,
        Paint()..color = _steelDark);
    canvas.drawCircle(Offset(doorCx, doorCy), doorR * 0.18,
        Paint()..color = _gold.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(doorCx, doorCy), doorR * 0.09,
        Paint()
          ..shader = RadialGradient(
            colors: [_goldLight, _goldDim],
          ).createShader(Rect.fromCircle(
              center: Offset(doorCx, doorCy), radius: doorR * 0.09)));

    // Door shine
    canvas.drawArc(
      Rect.fromCircle(center: Offset(doorCx - doorR * 0.18, doorCy - doorR * 0.18), radius: doorR * 0.55),
      -2.2, 0.9, false,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Handle bar
    final handleX = doorCx + doorR + 14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(handleX, doorCy), width: 8, height: doorR * 0.9),
          const Radius.circular(4)),
      Paint()..color = _steel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(handleX, doorCy), width: 8, height: doorR * 0.9),
          const Radius.circular(4)),
      Paint()..color = _gold.withOpacity(0.45)..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );
  }

  void _drawLockIndicator(Canvas canvas, Size size, double cx, double cy) {
    final vaultH = size.height * 0.58;
    final vaultY = cy - vaultH * 0.52;
    final indY = vaultY + vaultH * 0.88;
    final pulse = math.sin(animValue * math.pi * 2) * 0.5 + 0.5;

    // Lock icon container
    final iconCx = cx;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(iconCx, indY), width: 60, height: 22),
          const Radius.circular(11)),
      Paint()..color = _steelDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(iconCx, indY), width: 60, height: 22),
          const Radius.circular(11)),
      Paint()
        ..color = _gold.withOpacity(0.3 + pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Lock icon
    const lockSymbol = '🔒';
    final tp = TextPainter(
      text: const TextSpan(
        text: 'LOCKED',
        style: TextStyle(
          color: Color(0xFFD4A843),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(iconCx - tp.width / 2, indY - tp.height / 2));
  }

  void _drawGoldCoins(Canvas canvas, Size size, double cx, double cy) {
    final vaultH = size.height * 0.58;
    final baseY = cy + vaultH * 0.38;
    final vaultX = cx - size.width * 0.34;

    final stacks = [
      _Stack(x: cx + size.width * 0.14, count: 5),
      _Stack(x: cx + size.width * 0.24, count: 3),
      _Stack(x: cx + size.width * 0.31, count: 7),
    ];

    for (final s in stacks) {
      for (int i = 0; i < s.count; i++) {
        final y = baseY - i * 6.5;
        // Edge
        canvas.drawOval(
          Rect.fromCenter(center: Offset(s.x, y + 3), width: 28, height: 8),
          Paint()..color = _goldDim,
        );
        // Face
        canvas.drawOval(
          Rect.fromCenter(center: Offset(s.x, y), width: 28, height: 8),
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.2, -0.5),
              colors: [_goldLight, _gold, _goldDim],
            ).createShader(Rect.fromCenter(center: Offset(s.x, y), width: 28, height: 8)),
        );
        // Shine
        canvas.drawArc(
          Rect.fromCenter(center: Offset(s.x - 4, y - 1), width: 16, height: 5),
          -2.6, 1.0, false,
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _drawSecurityDots(Canvas canvas, Size size, double cx, double cy) {
    final vaultCy = cy - size.height * 0.04;
    final configs = [
      _Dot(angle: 0.4, dist: size.width * 0.44, symbol: '🛡'),
      _Dot(angle: math.pi - 0.4, dist: size.width * 0.42, symbol: '🔐'),
      _Dot(angle: math.pi * 0.55, dist: size.width * 0.46, symbol: '✓'),
    ];
    for (final d in configs) {
      final float = math.sin(animValue * math.pi * 2 + d.angle) * 4;
      final pos = Offset(
        cx + math.cos(d.angle) * d.dist,
        vaultCy + math.sin(d.angle) * d.dist * 0.65 + float,
      );

      canvas.drawCircle(pos, 16,
          Paint()..color = _steelDark);
      canvas.drawCircle(pos, 16,
          Paint()
            ..color = _gold.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);

      final tp = TextPainter(
        text: TextSpan(
          text: d.symbol,
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(SecureEarningsPainter old) => old.animValue != animValue;
}

class _Stack {
  final double x;
  final int count;
  const _Stack({required this.x, required this.count});
}

class _Dot {
  final double angle, dist;
  final String symbol;
  const _Dot({required this.angle, required this.dist, required this.symbol});
}
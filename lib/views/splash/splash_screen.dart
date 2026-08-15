import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../data/security/security_repository.dart';
import '../../utils/responsive.dart';

// ── Palette — premium light fintech (light green + beige + white) ──────────
const _bgTop = Color(0xFFF7F5F2); // soft warm beige-white
const _bgMid = Color(0xFFEFF5F1); // very light mint-white
const _bgBottom = Color(0xFFE4EEE8); // pale green-beige
const _lightGreen = Color(0xFF7DCB9E); // brand light green
const _lightGreenSoft = Color(0xFF9FDAB9); // soft green highlight
const _mint = Color(0xFFB8E5CA); // light mint
const _softTeal = Color(0xFF7DCB9E); // reuse light green
const _cardWhite = Color(0xFFFFFFFF);
const _glassBorder = Color(0x66FFFFFF);
const _textPrimary = Color(0xFF111827); // near-black — excellent contrast
const _textMuted = Color(0xFF6B7280); // neutral grey

/// App entry point.
///
/// This screen runs every time the app is launched (cold start) and decides
/// where the user should land:
///   • No saved auth token            -> onboarding / login flow
///   • Logged in but PIN not yet set  -> Set PIN flow (enter + confirm, 2x)
///   • Logged in and PIN already set  -> GPay-style PIN lock (enter, 1x)
///
/// IMPORTANT: this widget is deliberately kept visible on screen for a fixed
/// 3 seconds no matter how fast the auth check resolves, using a single
/// Timer that is completely independent of the animation controllers and of
/// the SharedPreferences lookup. This guarantees the branded splash is
/// always shown in full, and never gets skipped straight to onboarding/login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Fast one-shot entrance animation for the central logo/card.
  late final AnimationController _introController;
  // Slow, continuous, repeating animation driving every ambient motion:
  // orbit rotation, icon float, glow pulse, background drift and the
  // bottom loading indicator sweep.
  late final AnimationController _loopController;

  String? _resolvedRoute;
  bool _minTimeElapsed = false;

  static const _orbitItems = <_OrbitItem>[
    _OrbitItem(icon: Icons.shield_rounded, angleDeg: -90), // secure shield
    _OrbitItem(
      icon: Icons.account_balance_wallet_rounded,
      angleDeg: -18,
    ), // wallet
    _OrbitItem(icon: Icons.trending_up_rounded, angleDeg: 54), // growth chart
    _OrbitItem(icon: Icons.hub_rounded, angleDeg: 126), // referral network
    _OrbitItem(icon: Icons.insights_rounded, angleDeg: 198), // analytics
  ];

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Wait until the first frame is fully painted before starting the
    // animations and the minimum-time timer. This ensures the animation and
    // the 3-second window begin only after the Flutter splash is actually
    // visible on screen — not while the native/system splash is still
    // showing during engine cold-start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _introController.forward();

      // Resolve where to navigate in the background.
      _resolveNextRoute().then((route) {
        if (!mounted) return;
        _resolvedRoute = route;
        _maybeNavigate();
      });

      // Enforce a fixed minimum splash duration, independent of anything else.
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _minTimeElapsed = true;
        _maybeNavigate();
      });
    });
  }

  void _maybeNavigate() {
    if (!mounted) return;
    if (_resolvedRoute == null || !_minTimeElapsed) return;
    Navigator.pushReplacementNamed(context, _resolvedRoute!);
  }

  Future<String> _resolveNextRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('logged_in_user_id') ?? '';

      if (token == null || token.isEmpty || userId.isEmpty) {
        // Not logged in - show onboarding only on the first app launch;
        // every launch after that (still logged out) goes straight to
        // login instead of repeating onboarding.
        final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
        return onboardingSeen ? AppRoutes.login : AppRoutes.onboarding;
      }

      final existingPin = prefs.getString('app_pin_$userId') ?? '';
      if (existingPin.isEmpty) {
        // No PIN cached on this device — but it may already be set up on
        // a different device for this account. Ask the backend before
        // forcing the user through PIN setup again; the app-pin screen
        // will verify the entered PIN against the account (backend) on
        // its own if this device still has nothing cached.
        final status = await SecurityRepository().getPinsStatus();
        if (status.loginPinSet) {
          return AppRoutes.appPin;
        }
        // Logged in but the account genuinely has no Login PIN yet ->
        // set it now (enter + confirm, 2 times).
        return AppRoutes.setPassword;
      }

      // Logged in and PIN already configured -> ask for it once,
      // every time the app is opened (GPay-style lock).
      return AppRoutes.appPin;
    } catch (_) {
      // If SharedPreferences fails for any reason, fail safe to onboarding
      // rather than getting stuck on the splash screen forever.
      return AppRoutes.onboarding;
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orbitRadius = math.min(size.width, size.height) * 0.225;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgTop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Soft, slowly drifting light-green gradient background.
            AnimatedBuilder(
              animation: _loopController,
              builder: (context, _) {
                final shift =
                    math.sin(_loopController.value * 2 * math.pi) * 0.15;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + shift, -1 - shift),
                      end: Alignment(1 - shift, 1 + shift),
                      colors: const [_bgTop, _bgMid, _bgBottom],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Faint dot-grid overlay for subtle depth.
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

            // Ambient floating particles.
            AnimatedBuilder(
              animation: _loopController,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(t: _loopController.value),
                size: Size(size.width, size.height),
              ),
            ),

            // Large soft pulsing glow centered behind the composition.
            AnimatedBuilder(
              animation: _loopController,
              builder: (context, _) {
                final pulse =
                    0.85 + 0.15 * math.sin(_loopController.value * 2 * math.pi);
                return Align(
                  alignment: const Alignment(0, -0.08),
                  child: Container(
                    width: size.width * 1.15 * pulse,
                    height: size.width * 1.15 * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _lightGreen.withOpacity(0.22),
                          _softTeal.withOpacity(0.10),
                          _lightGreen.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Orbit composition: center glass card + 5 orbiting
                  // investment concept icons (shield, wallet, growth chart,
                  // referral network, analytics) connected by faint lines.
                  SizedBox(
                    width: orbitRadius * 2 + 90.w,
                    height: orbitRadius * 2 + 90.h,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _introController,
                        _loopController,
                      ]),
                      builder: (context, _) {
                        final introT = Curves.easeOutBack.transform(
                          _introController.value,
                        );
                        final rotation = _loopController.value * 2 * math.pi;

                        return Opacity(
                          opacity: _introController.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.82 + 0.18 * introT,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Connector lines from center to each orbiting icon.
                                CustomPaint(
                                  size: Size(
                                    orbitRadius * 2 + 90.w,
                                    orbitRadius * 2 + 90.h,
                                  ),
                                  painter: _OrbitLinesPainter(
                                    items: _orbitItems,
                                    radius: orbitRadius,
                                    rotation: rotation,
                                    pulse: _loopController.value,
                                  ),
                                ),

                                // Orbiting icon badges.
                                for (final item in _orbitItems)
                                  _OrbitBadge(
                                    item: item,
                                    radius: orbitRadius,
                                    rotation: rotation,
                                    loopValue: _loopController.value,
                                  ),

                                // Central glassmorphic logo card.
                                _CenterLogoCard(pulse: _loopController.value),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 36.h),

                  // App name with soft light-green gradient shader.
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        _textPrimary,
                        Color(0xFF3D9463),
                        Color(0xFF4CAF7D),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'MoneyTries',
                      style: TextStyle(
                        fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Tagline.
                  Text(
                    'INVEST SMART. EARN DAILY. GROW SECURELY.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                      letterSpacing: 1.6,
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Premium animated loading indicator.
                  AnimatedBuilder(
                    animation: _loopController,
                    builder: (context, _) {
                      // Smooth ping-pong sweep, independent cycle length.
                      final cycle = (_loopController.value * 12) % 2.4;
                      final sweep = cycle <= 1.2
                          ? Curves.easeInOut.transform(cycle / 1.2)
                          : 1 - Curves.easeInOut.transform((cycle - 1.2) / 1.2);

                      return SizedBox(
                        width: 148.w,
                        height: 5.h,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Container(
                                color: _textPrimary.withOpacity(0.08),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Align(
                                alignment: Alignment(sweep * 2 - 1, 0),
                                widthFactor: 0.42,
                                child: Container(
                                  height: 5.h,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.r),
                                    gradient: const LinearGradient(
                                      colors: [_lightGreen, _mint, _softTeal],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _lightGreen.withOpacity(0.45),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 44.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model for orbiting icon badges ─────────────────────────────────────
class _OrbitItem {
  final IconData icon;
  final double angleDeg; // base angle in degrees, 0 = 3 o'clock

  const _OrbitItem({required this.icon, required this.angleDeg});
}

// ── Central glassmorphic logo card ──────────────────────────────────────────
class _CenterLogoCard extends StatelessWidget {
  final double pulse;
  const _CenterLogoCard({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final glow = 0.20 + 0.10 * math.sin(pulse * 2 * math.pi);
    return Container(
      width: 128.w,
      height: 128.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: _lightGreen.withOpacity(glow),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _textPrimary.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: _glassBorder, width: 1.2.r),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _cardWhite.withOpacity(0.85),
                  _mint.withOpacity(0.35),
                  _bgBottom.withOpacity(0.55),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: Image.asset(
                'assets/images/moneytries_mark.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.trending_up_rounded,
                  size: 54.sp,
                  color: _lightGreen,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── One orbiting investment-concept icon badge ──────────────────────────────
class _OrbitBadge extends StatelessWidget {
  final _OrbitItem item;
  final double radius;
  final double rotation; // global orbit rotation in radians
  final double loopValue;

  const _OrbitBadge({
    required this.item,
    required this.radius,
    required this.rotation,
    required this.loopValue,
  });

  @override
  Widget build(BuildContext context) {
    final angle = item.angleDeg * math.pi / 180 + rotation;
    final bob = math.sin(loopValue * 2 * math.pi + item.angleDeg) * 5;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius + bob;
    final glow =
        0.18 + 0.12 * math.sin(loopValue * 2 * math.pi + item.angleDeg);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 46.w,
        height: 46.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _glassBorder, width: 1.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _cardWhite.withOpacity(0.80),
              _lightGreenSoft.withOpacity(0.45),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _lightGreen.withOpacity(glow),
              blurRadius: 16,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Icon(
                item.icon,
                size: 20.sp,
                color: const Color(0xFF4CAF7D),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────

/// Faint connecting lines from the center to each orbiting badge, evoking a
/// referral/analytics network radiating from the app.
class _OrbitLinesPainter extends CustomPainter {
  final List<_OrbitItem> items;
  final double radius;
  final double rotation;
  final double pulse;

  _OrbitLinesPainter({
    required this.items,
    required this.radius,
    required this.rotation,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = 0.14 + 0.10 * math.sin(pulse * 2 * math.pi);

    for (final item in items) {
      final angle = item.angleDeg * math.pi / 180 + rotation;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            _lightGreen.withOpacity(0.0),
            _lightGreen.withOpacity(opacity),
          ],
        ).createShader(Rect.fromPoints(center, end))
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      canvas.drawLine(center, end, paint);
    }

    // Faint orbit ring.
    final ringPaint = Paint()
      ..color = _lightGreen.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitLinesPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
}

/// Very subtle dot-grid backdrop for a futuristic fintech feel.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _lightGreen.withOpacity(0.06);
    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// Slow-drifting ambient particles for depth and premium polish.
class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter({required this.t});

  static final _seeds = List.generate(14, (i) {
    final rnd = math.Random(i * 37);
    return Offset(rnd.nextDouble(), rnd.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _seeds.length; i++) {
      final seed = _seeds[i];
      final phase = (t + i / _seeds.length) % 1.0;
      final dy = size.height * (1 - phase);
      final dx = seed.dx * size.width + math.sin(phase * 2 * math.pi + i) * 10;
      final opacity = (math.sin(phase * math.pi)).clamp(0.0, 1.0) * 0.30;
      final radius = 1.0 + (i % 3) * 0.6;

      final paint = Paint()..color = _lightGreen.withOpacity(opacity);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.t != t;
}

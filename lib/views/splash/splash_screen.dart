import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';

// ── Palette (matches Moneytries theme) ───────────────────────────────────────
const _navyDark = Color(0xFF0A1A22);
const _navyMid = Color(0xFF0E2A2E);
const _tealDark = Color(0xFF0F3B36);
const _brandGreen = Color(0xFF3D9E6A);
const _brandGreenLight = Color(0xFF6FD3A0);
const _taglineGray = Color(0xFFB9C2C6);

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
/// Timer that is completely independent of the animation controller and of
/// the SharedPreferences lookup. This guarantees the branded splash (logo
/// box, "MoneyTries" title, tagline, loading bar) is always shown in full,
/// and never gets skipped straight to onboarding/login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  String? _resolvedRoute;
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();

    // Short, snappy intro animation (logo scales/fades in fast so it is
    // never "invisible" for long even on a quick glance).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Resolve where to navigate in the background.
    _resolveNextRoute().then((route) {
      _resolvedRoute = route;
      _maybeNavigate();
    });

    // Enforce a fixed minimum splash duration, independent of anything else.
    Future.delayed(const Duration(seconds: 3), () {
      _minTimeElapsed = true;
      _maybeNavigate();
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
        // Not logged in - go through the normal onboarding/login flow.
        return AppRoutes.onboarding;
      }

      final existingPin = prefs.getString('app_pin_$userId') ?? '';
      if (existingPin.isEmpty) {
        // Logged in but never finished setting an app PIN -> set it now
        // (enter + confirm, 2 times).
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _navyDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen dark navy -> teal gradient background.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navyDark, _navyMid, _tealDark],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Subtle radial glow centered behind the logo.
            Align(
              alignment: const Alignment(0, -0.15),
              child: Container(
                width: size.width * 1.1,
                height: size.width * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _brandGreen.withOpacity(0.16),
                      _brandGreen.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Main content. Title/tagline/loader are shown at full opacity
            // immediately - only the logo does a quick scale+fade intro -
            // so there is no window where the screen looks "empty".
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 4),

                  // Logo: quick fade + scale.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = Curves.easeOutBack.transform(_controller.value);
                      return Opacity(
                        opacity: _controller.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.85 + (0.15 * t),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 132,
                      height: 132,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1F1D),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _brandGreen.withOpacity(0.35),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/moneytries_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.trending_up_rounded,
                            size: 56,
                            color: _brandGreenLight,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // App name - visible immediately, no delayed fade.
                  Text(
                    'MoneyTries',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline - visible immediately, no delayed fade.
                  Text(
                    'INVEST SMART. GROW EVERY DAY.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _taglineGray,
                      letterSpacing: 1.4,
                    ),
                  ),

                  const Spacer(flex: 5),

                  // Thin rounded loading indicator at the bottom center.
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 120,
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _brandGreen,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

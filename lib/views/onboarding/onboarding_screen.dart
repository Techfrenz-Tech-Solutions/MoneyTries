import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/onboarding_slide_widget.dart';
import '../../widgets/onboarding_indicator.dart';
import '../../routes/app_routes.dart';

// ── Mint / Sage Palette — matches banner gradient ─────────────────────────────
const _bgBase          = Color(0xFFF0F7F3); // soft mint-white base
const _bgMid           = Color(0xFFE6F2EB); // lifted mint layer
const _meshAccent1     = Color(0xFFB8DECA); // light sage mesh highlight
const _meshAccent2     = Color(0xFFCCE8D8); // secondary mesh
const _shimmer         = Color(0xFF86C9A0); // banner mint shimmer
const _appNameColor    = Color(0xFF2D7A52); // deep sage app name
const _skipColor       = Color(0xFF5A9E7A); // mid sage SKIP/HELP
const _titleColor      = Color(0xFF1E6645); // rich sage headline
const _bodyColor       = Color(0xFF4A7A60); // muted sage body
const _tosColor        = Color(0xFF7AAF94); // light sage terms
const _buttonColor     = Color(0xFF3D9E6A); // banner sage CTA
const _buttonTextColor = Color(0xFFFFFFFF); // white on sage button
const _orbColor1       = Color(0xFF86C9A0); // light mint orb
const _orbColor2       = Color(0xFF4DAA75); // mid sage orb

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<OnboardingViewModel>();
    final mq     = MediaQuery.of(context);
    final isLast = vm.isLastPage;

    // Image card: ~28% of screen height
    final cardHeight = mq.size.height * 0.28;

    // Slightly more gap to push image card lower — ~15% of screen height
    final headerToCardGap = mq.size.height * 0.15;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgBase,
        body: Stack(
          children: [
            // ── Luxury background: deep emerald mesh + orbs ──────────────
            const Positioned.fill(child: _LuxuryBackground()),

            // ── Main content ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Top bar: app name + SKIP/HELP ─────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // App name with subtle gold underline accent
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'MoneyTries',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _appNameColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 32,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _appNameColor.withOpacity(0.8),
                                      _appNameColor.withOpacity(0.0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: isLast
                                ? () {}
                                : () => _navigateToLogin(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _skipColor.withOpacity(0.45),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: _skipColor.withOpacity(0.08),
                              ),
                              child: Text(
                                isLast ? 'HELP' : 'SKIP',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _skipColor,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Gap: push image card lower ─────────────────────────
                    SizedBox(height: headerToCardGap),

                    // ── Image card: 36px margins, r:20 ────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: SizedBox(
                        height: cardHeight,
                        child: PageView.builder(
                          controller: vm.pageController,
                          onPageChanged: vm.onPageChanged,
                          physics: const BouncingScrollPhysics(),
                          itemCount: vm.totalPages,
                          itemBuilder: (_, i) => OnboardingSlideWidget(
                            slide: vm.slides[i],
                            isActive: vm.currentPage == i,
                            slideIndex: i,
                          ),
                        ),
                      ),
                    ),

                    // ── 32px gap card → title ──────────────────────────────
                    const SizedBox(height: 32),

                    // ── Title + description ────────────────────────────────
                    _AnimatedTextBlock(
                      title: vm.slides[vm.currentPage].title,
                      description: vm.slides[vm.currentPage].description,
                      pageKey: vm.currentPage,
                    ),

                    // ── Spacer ─────────────────────────────────────────────
                    const Spacer(),

                    // ── Indicators ────────────────────────────────────────
                    OnboardingIndicator(
                      count: vm.totalPages,
                      current: vm.currentPage,
                    ),

                    const SizedBox(height: 24),

                    // ── CTA Button ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: _CTAButton(
                          key: ValueKey(isLast ? 'start' : 'next'),
                          label: isLast ? 'GET STARTED' : 'NEXT',
                          onTap: isLast
                              ? () => _navigateToLogin(context)
                              : vm.nextPage,
                        ),
                      ),
                    ),

                    // ── Terms: last slide only ─────────────────────────────
                    AnimatedOpacity(
                      opacity: isLast ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'By continuing, you agree to our Terms of Service',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _tosColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    SizedBox(height: mq.padding.bottom > 0 ? 16 : 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Luxury Background Painter ─────────────────────────────────────────────────
// Deep forest emerald base with radial orb glows, mesh shimmer lines,
// and a diagonal gradient — premium, not black.
class _LuxuryBackground extends StatefulWidget {
  const _LuxuryBackground();

  @override
  State<_LuxuryBackground> createState() => _LuxuryBackgroundState();
}

class _LuxuryBackgroundState extends State<_LuxuryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        painter: _BackgroundPainter(_pulse.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double pulse;
  _BackgroundPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // ── Base gradient: soft mint-white diagonal ───────────────────────────
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFF4FAF6), // top-left: lightest mint
          Color(0xFFEAF4EE), // mid: soft sage
          Color(0xFFDFF0E7), // bottom-right: warm mint
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ── Top-right mint orb glow ───────────────────────────────────────────
    final orb1Opacity = 0.22 + pulse * 0.10;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xFF86C9A0).withOpacity(orb1Opacity),
          Color(0xFF4DAA75).withOpacity(orb1Opacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.88, size.height * 0.10),
          radius: size.width * 0.60,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.10),
      size.width * 0.60,
      orb1Paint,
    );

    // ── Bottom-left sage orb glow ────────────────────────────────────────
    final orb2Opacity = 0.18 + pulse * 0.08;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xFF4DAA75).withOpacity(orb2Opacity),
          Color(0xFF3D9E6A).withOpacity(orb2Opacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.12, size.height * 0.90),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.90),
      size.width * 0.55,
      orb2Paint,
    );

    // ── Centre ambient mint glow ─────────────────────────────────────────
    final orbCenterOpacity = 0.10 + pulse * 0.05;
    final orbCenter = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xFF86C9A0).withOpacity(orbCenterOpacity),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.42),
          radius: size.width * 0.75,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.75,
      orbCenter,
    );

    // ── Diagonal shimmer mesh lines ───────────────────────────────────────
    final meshPaint = Paint()
      ..color = const Color(0xFF86C9A0).withOpacity(0.14)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const spacing = 52.0;
    final lineCount = (size.width + size.height) ~/ spacing + 4;
    for (int i = -2; i < lineCount; i++) {
      final x = i * spacing.toDouble();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        meshPaint,
      );
    }

    // ── Top edge sage shimmer strip ───────────────────────────────────────
    final topShimmer = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Color(0xFF3D9E6A).withOpacity(0.10 + pulse * 0.05),
          Color(0xFF4DAA75).withOpacity(0.14 + pulse * 0.06),
          Color(0xFF3D9E6A).withOpacity(0.10 + pulse * 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 2), topShimmer);

    // ── Subtle light vignette (edges lighter, draws eye to centre) ────────
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Color(0xFF86C9A0).withOpacity(0.12),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.pulse != pulse;
}

// ── Animated title + description ─────────────────────────────────────────────
class _AnimatedTextBlock extends StatefulWidget {
  final String title;
  final String description;
  final int pageKey;

  const _AnimatedTextBlock({
    required this.title,
    required this.description,
    required this.pageKey,
  });

  @override
  State<_AnimatedTextBlock> createState() => _AnimatedTextBlockState();
}

class _AnimatedTextBlockState extends State<_AnimatedTextBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade   = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedTextBlock old) {
    super.didUpdateWidget(old);
    if (old.pageKey != widget.pageKey) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _offset,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title: warm gold, bold
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Thin gold divider accent under title
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _titleColor.withOpacity(0.0),
                      _titleColor.withOpacity(0.5),
                      _titleColor.withOpacity(0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 10),
              // Description: sage-white
              Text(
                widget.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _bodyColor,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CTA button: pill r:50, 56px tall, full width, warm gold gradient ──────────
class _CTAButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CTAButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF56B47E), // light mint highlight
                Color(0xFF3D9E6A), // banner sage
                Color(0xFF2D8558), // deep sage shadow
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3D9E6A).withOpacity(0.32),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFF3D9E6A).withOpacity(0.14),
                blurRadius: 40,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _buttonTextColor,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: _buttonTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/onboarding_slide_widget.dart';
import '../../widgets/onboarding_indicator.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';
import '../../widgets/painters/referral_illustration_painter.dart';

// ── Onboarding palette — matches the reference design (cream/white bg,
// deep sage headline, muted sage body, mint CTA gradient) ─────────────────
const _bg = Color(0xFFFBF9F5); // near-white / cream background
const _appBarTitle = Color(0xFF16281F); // near-black "MoneyTries" title
const _backIcon = Color(0xFF2D7A52); // deep green back arrow / links
const _skipText = Color(0xFF2D7A52); // deep green Skip label
const _titleColor = Color(0xFF16281F); // near-black headline
const _bodyColor = Color(0xFF7C8B83); // muted sage body / login text
const _stepLabelColor = Color(0xFFA9B4AD); // "STEP X OF Y" caption
const _buttonTextColor = Color(0xFFFFFFFF); // white on sage button

// ── Referral (last) screen illustration card palette ──────────────────────
const _rCardCreamA = Color(0xFFF6EFE3); // illustration card gradient top
const _rCardCreamB = Color(0xFFEDE3D0); // illustration card gradient bottom
const _rBadgeText = Color(0xFF16281F); // "Exclusive Rewards" badge text

const _onboardingSeenKey = 'onboarding_seen';

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

  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  void _navigateToLogin(BuildContext context) {
    _markOnboardingSeen();
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _navigateToRegister(BuildContext context) {
    _markOnboardingSeen();
    Navigator.pushReplacementNamed(context, AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final mq = MediaQuery.of(context);
    final isLast = vm.isLastPage;

    final isReferral = vm.currentSlide.isReferral;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: Back · centered "MoneyTries" · Skip ─────────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: Row(
                    children: [
                      // Back arrow — hidden on the first slide (nothing
                      // to go back to). An invisible spacer of the same
                      // size keeps "MoneyTries" perfectly centered.
                      vm.currentPage > 0
                          ? GestureDetector(
                              onTap: () {
                                vm.pageController.previousPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                Icons.arrow_back,
                                color: _backIcon,
                                size: 22.sp,
                              ),
                            )
                          : SizedBox(width: 22.sp, height: 22.sp),
                      Expanded(
                        child: Text(
                          'MoneyTries',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: _appBarTitle,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateToRegister(context),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: _skipText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Gap between header and image card ───────────────────
                SizedBox(height: 8.h),

                // ── Image card ──────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: mq.size.width * (isReferral ? 0.78 : 0.86),
                        child: PageView.builder(
                          controller: vm.pageController,
                          onPageChanged: vm.onPageChanged,
                          physics: const BouncingScrollPhysics(),
                          itemCount: vm.totalPages,
                          itemBuilder: (_, i) {
                            final slide = vm.slides[i];
                            if (slide.isReferral) {
                              return _ReferralIllustrationCard(
                                animate: vm.currentPage == i,
                                imagePath: slide.imagePath,
                              );
                            }
                            return OnboardingSlideWidget(
                              slide: slide,
                              isActive: vm.currentPage == i,
                              slideIndex: i,
                            );
                          },
                        ),
                      ),

                      // "Exclusive Rewards" badge — referral screen only.
                      // (Slides 1 & 2 use illustration assets with the
                      // badge already baked into the artwork.)
                      if (isReferral)
                        Positioned(
                          top: 14.h,
                          right: 4.w,
                          child: IgnorePointer(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14.sp,
                                    color: _backIcon,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Exclusive Rewards',
                                    style: TextStyle(
                                      fontFamily: 'Times New Roman',
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _rBadgeText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Gap card → title: slightly more space pushes text down ──
                SizedBox(height: 44.h),

                // ── Title + description ────────────────────────────────
                _AnimatedTextBlock(
                  title: vm.slides[vm.currentPage].title,
                  description: vm.slides[vm.currentPage].description,
                  pageKey: vm.currentPage,
                  isReferral: isReferral,
                ),

                // ── Spacer ─────────────────────────────────────────────
                const Spacer(),

                // ── CTA Button ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _CTAButton(
                      key: ValueKey(isLast ? 'start' : 'next'),
                      label: isLast ? 'Get Started' : 'Next',
                      onTap: isLast
                          ? () => _navigateToRegister(context)
                          : vm.nextPage,
                    ),
                  ),
                ),

                // ── "Already have an account? Login" ───────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                  ).add(EdgeInsets.only(top: 14.h)),
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => _navigateToLogin(context),
                      behavior: HitTestBehavior.opaque,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 13.sp,
                            color: _bodyColor,
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: _backIcon,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Dot indicator ───────────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(top: 14.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: OnboardingIndicator(
                      count: vm.totalPages,
                      current: vm.currentPage,
                    ),
                  ),
                ),

                // ── "STEP X OF Y" caption ───────────────────────────────
                Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'STEP ${vm.currentPage + 1} OF ${vm.totalPages}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: _stepLabelColor,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: mq.padding.bottom > 0 ? 16.h : 28.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated title + description ─────────────────────────────────────────────
class _AnimatedTextBlock extends StatefulWidget {
  final String title;
  final String description;
  final int pageKey;
  final bool isReferral;

  const _AnimatedTextBlock({
    required this.title,
    required this.description,
    required this.pageKey,
    this.isReferral = false,
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
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
    return SizedBox(
      width: double.infinity,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _offset,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: widget.isReferral ? 26.sp : 24.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    height: widget.isReferral ? 1.25 : 1.2,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: widget.isReferral ? 14.h : 10.h),
                // Description
                Text(
                  widget.description,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 14.sp,
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
      ),
    );
  }
}

// ── CTA button: pill r:50, 56px tall, full width, sage gradient ──────────
class _CTAButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CTAButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5BC487), // light mint highlight
                Color(0xFF4CAF7D), // banner sage
                Color(0xFF2D8558), // deep sage shadow
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(50.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF7D).withOpacity(0.32),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFF4CAF7D).withOpacity(0.14),
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
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _buttonTextColor,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(width: 10.w),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18.sp,
                color: _buttonTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Referral illustration card (Step 3) ────────────────────────────────────
// Rounded cream card showing the reference gift-exchange illustration
// (assets/images/onboarding_referral.png). Falls back to the painted
// illustration if the asset hasn't been added yet, so the app never crashes.
class _ReferralIllustrationCard extends StatefulWidget {
  final bool animate;
  final String imagePath;
  const _ReferralIllustrationCard({
    required this.animate,
    required this.imagePath,
  });

  @override
  State<_ReferralIllustrationCard> createState() =>
      _ReferralIllustrationCardState();
}

class _ReferralIllustrationCardState extends State<_ReferralIllustrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_rCardCreamA, _rCardCreamB],
        ),
        boxShadow: [
          BoxShadow(
            color: _backIcon.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Image.asset(
          widget.imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: ReferralIllustrationPainter(animValue: _ctrl.value),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

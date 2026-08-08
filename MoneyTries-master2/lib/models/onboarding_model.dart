class OnboardingSlide {
  final String title;
  final String description;
  final String illustrationTag;
  final String imagePath;
  // When true, this slide renders the dedicated referral-style full
  // screen (custom app bar, badge, illustration, CTA) instead of the
  // shared onboarding chrome.
  final bool isReferral;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.illustrationTag,
    required this.imagePath,
    this.isReferral = false,
  });
}

class OnboardingModel {
  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      title: 'Choose Your\nInvestment Plan',
      description:
          'Select a plan that suits you. Invest once, earn daily ROI, and get your amount back on maturity.',
      illustrationTag: 'plans',
      imagePath: 'assets/images/onboarding_plans.png',
    ),
    OnboardingSlide(
      title: 'Invest Smart,\nGrow Every Day',
      description:
          'Secure your future with smart\ninvestments, daily passive income,\nand easy withdrawals.',
      illustrationTag: 'smart_invest',
      imagePath: 'assets/images/onboarding_smart_invest.png',
    ),
    OnboardingSlide(
      title: 'Grow Your Circle, Earn Rewards',
      description:
          'Invite friends using your referral code and earn exclusive rewards when they start their investment journey.',
      illustrationTag: 'referral',
      imagePath: 'assets/images/onboarding_referral.png',
      isReferral: true,
    ),
  ];
}
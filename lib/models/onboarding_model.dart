class OnboardingSlide {
  final String title;
  final String description;
  final String illustrationTag;
  final String imagePath;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.illustrationTag,
    required this.imagePath,
  });
}

class OnboardingModel {
  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      title: 'Earn 0.3% Daily Bonus',
      description:
          'Start mining instantly and earn 0.3% daily on your invested balance.',
      illustrationTag: 'grow',
      imagePath: 'assets/images/onboarding_grow.jpg',
    ),
    OnboardingSlide(
      title: 'Smart Investments',
      description:
          'Access diverse investment portfolios managed by experts and AI-driven insights.',
      illustrationTag: 'invest',
      imagePath: 'assets/images/onboarding_invest.png',
    ),
    OnboardingSlide(
      title: 'Secure Earnings',
      description:
          'Your wealth is protected by bank-grade security and end-to-end encryption.',
      illustrationTag: 'secure',
      imagePath: 'assets/images/onboarding_secure.jpg',
    ),
  ];
}
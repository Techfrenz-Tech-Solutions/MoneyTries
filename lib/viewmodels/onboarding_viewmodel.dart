import 'package:flutter/material.dart';
import '../models/onboarding_model.dart';

class OnboardingViewModel extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentPage = 0;

  int get currentPage => _currentPage;
  int get totalPages => OnboardingModel.slides.length;
  bool get isLastPage => _currentPage == totalPages - 1;

  List<OnboardingSlide> get slides => OnboardingModel.slides;

  OnboardingSlide get currentSlide => slides[_currentPage];

  void onPageChanged(int index) {
    _currentPage = index;
    notifyListeners();
  }

  void nextPage() {
    if (!isLastPage) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToPage(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}

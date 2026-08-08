// lib/widgets/animations/app_page_route.dart
//
// A drop-in replacement for MaterialPageRoute that adds a premium
// fade + gentle-slide transition (the same combination used by most
// modern fintech apps). Pop uses the reverse of the same curve so back
// navigation feels symmetric rather than a jarring platform default.
//
// Usage — wire once in main.dart via `onGenerateRoute` (see main.dart),
// or use directly: Navigator.push(context, AppPageRoute(page: SomeScreen()))
import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppPageRoute({required this.page, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved);
            // The incoming page also very slightly scales/fades the outgoing
            // page back, giving the transition depth instead of a flat swap.
            final outgoingFade = Tween<double>(begin: 1, end: 0.92).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: slide,
                child: FadeTransition(
                  opacity: outgoingFade,
                  child: child,
                ),
              ),
            );
          },
        );
}
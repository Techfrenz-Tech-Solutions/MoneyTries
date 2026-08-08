// lib/widgets/animations/animated_nav_icon.dart
//
// Wrap a bottom-nav icon with this to get a small "bump" scale + a
// color cross-fade the moment `selected` flips to true, instead of an
// instant color swap. Only bumps on the true transition (not on every
// rebuild), so it won't re-trigger from unrelated parent setState calls.
import 'package:flutter/material.dart';

class AnimatedNavIcon extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final double size;
  final Color selectedColor;
  final Color unselectedColor;

  const AnimatedNavIcon({
    super.key,
    required this.icon,
    required this.selected,
    required this.size,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _bump = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bump,
      builder: (context, child) => Transform.scale(scale: _bump.value, child: child),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          widget.icon,
          key: ValueKey(widget.selected),
          size: widget.size,
          color: widget.selected ? widget.selectedColor : widget.unselectedColor,
        ),
      ),
    );
  }
}
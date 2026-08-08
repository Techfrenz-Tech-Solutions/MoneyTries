// lib/widgets/premium/shimmer_skeleton.dart
//
// Generic shimmer-sweep skeleton box for premium loading placeholders —
// pairs with ShimmerNetworkImage (image-specific) for everything else:
// text lines, stat tiles, list rows, card outlines, etc. Drop it in
// wherever content is still loading instead of a bare spinner.
import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor = const Color(0xFFEDEBE6),
    this.highlightColor = const Color(0xFFFAF9F6),
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(1 + 3 * t, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Convenience stack of skeleton lines — e.g. for a loading text block.
class ShimmerSkeletonLines extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final double lastLineWidthFraction;

  const ShimmerSkeletonLines({
    super.key,
    this.lines = 3,
    this.lineHeight = 12,
    this.spacing = 8,
    this.lastLineWidthFraction = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
          child: FractionallySizedBox(
            widthFactor: isLast ? lastLineWidthFraction : 1.0,
            alignment: Alignment.centerLeft,
            child: ShimmerSkeleton(
              height: lineHeight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
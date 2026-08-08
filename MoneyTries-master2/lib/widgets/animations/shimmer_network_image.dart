// lib/widgets/animations/shimmer_network_image.dart
//
// Drop-in replacement for Image.network that shows a soft shimmer
// placeholder while loading and cross-fades into the loaded image.
// Keeps the same fit/errorBuilder ergonomics so it swaps in with a
// one-line change wherever Image.network is used today.
import 'package:flutter/material.dart';

class ShimmerNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Color baseColor;
  final Color highlightColor;
  final Map<String, String>? headers;

  const ShimmerNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.baseColor = const Color(0xFFE7F3EC),
    this.highlightColor = const Color(0xFFF6FBF8),
    this.headers,
  });

  @override
  State<ShimmerNetworkImage> createState() => _ShimmerNetworkImageState();
}

class _ShimmerNetworkImageState extends State<ShimmerNetworkImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _shimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _shimmerController.value;
            return LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: Container(color: widget.baseColor),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: widget.fit,
      headers: widget.headers,
      errorBuilder: widget.errorBuilder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          // Loaded — cross-fade the shimmer out for a soft reveal instead
          // of a hard pop-in.
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: child,
          );
        }
        return _shimmer();
      },
    );
  }
}
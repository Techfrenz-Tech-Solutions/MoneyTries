import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

/// A WhatsApp-style, full-screen profile photo viewer.
///
/// Features:
///  • Smooth Hero animation that morphs the circular thumbnail into a
///    square full-screen image (and back).
///  • Blurred + dimmed backdrop behind the image.
///  • Pinch-to-zoom and pan via [InteractiveViewer].
///  • Double-tap to zoom in/out.
///  • Vertical drag-to-dismiss with a live fade + follow effect.
///  • Close (X) button and tap-outside-to-close.
///
/// Usage:
/// ```dart
/// Hero(
///   tag: 'profile-avatar-hero',
///   child: ClipOval(child: Image.network(avatarUrl)),
/// )
/// // on tap:
/// ProfilePhotoViewer.show(
///   context,
///   imageUrl: avatarUrl,
///   heroTag: 'profile-avatar-hero',
///   userName: userName,
///   sourceRadius: 55,
/// );
/// ```
class ProfilePhotoViewer extends StatefulWidget {
  const ProfilePhotoViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.userName,
    this.sourceRadius = 55,
  });

  /// URL of the full-quality image to display.
  final String imageUrl;

  /// Must match the [Hero] tag used on the thumbnail that triggered this
  /// viewer, so the flight animation connects the two.
  final String heroTag;

  /// No longer displayed (the name caption below the image was removed).
  /// Kept as an optional parameter so existing call sites that pass a
  /// `userName` don't need to change.
  final String? userName;

  /// Radius (in logical pixels) of the circular thumbnail this viewer is
  /// flying in from. Used to morph the Hero shape from a circle to a
  /// square during the transition, matching WhatsApp's effect.
  final double sourceRadius;

  /// Opens the viewer as a transparent, fade-in overlay route.
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
    String? userName,
    double sourceRadius = 55,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoViewer(
            imageUrl: imageUrl,
            heroTag: heroTag,
            userName: userName,
            sourceRadius: sourceRadius,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> {
  final TransformationController _transformController =
      TransformationController();

  TapDownDetails? _doubleTapDetails;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isZoomed = false;

  static const double _dismissDragThreshold = 110.0;
  static const double _dismissVelocityThreshold = 700.0;
  static const double _maxDragFade = 260.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  bool get _isNetworkImage => widget.imageUrl.startsWith('http');

  /// Builds the image widget, supporting both a remote URL and a local
  /// on-device file path (e.g. a freshly picked photo that hasn't been
  /// uploaded yet).
  Widget _buildImage({BoxFit fit = BoxFit.cover}) {
    if (_isNetworkImage) {
      return Image.network(
        widget.imageUrl,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.white10,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: Colors.white10,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 90, color: Colors.white54),
        ),
      );
    }
    return Image.file(
      File(widget.imageUrl),
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.person, size: 90, color: Colors.white54),
      ),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    if (currentScale > 1.01) {
      _transformController.value = Matrix4.identity();
      setState(() => _isZoomed = false);
    } else {
      const targetScale = 2.6;
      final dx = -position.dx * (targetScale - 1);
      final dy = -position.dy * (targetScale - 1);
      _transformController.value = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
      setState(() => _isZoomed = true);
    }
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    setState(() => _isDragging = true);
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() => _dragOffset += details.delta);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = _dragOffset.dy.abs() > _dismissDragThreshold ||
        velocity.abs() > _dismissVelocityThreshold;

    if (shouldDismiss) {
      _close();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress =
        (_dragOffset.dy.abs() / _maxDragFade).clamp(0.0, 1.0);
    final backdropOpacity = 1.0 - dragProgress;
    final imageScale = 1.0 - (dragProgress * 0.12);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Dimmed + blurred backdrop ──
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _isDragging ? 0 : 180),
                opacity: backdropOpacity,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(color: Colors.black.withOpacity(0.88)),
                ),
              ),
            ),
          ),

          // ── Image + caption, draggable to dismiss ──
          Positioned.fill(
            child: AnimatedContainer(
              duration: Duration(milliseconds: _isDragging ? 0 : 220),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _dragOffset.dy, 0)
                ..scale(imageScale),
              transformAlignment: Alignment.center,
              child: Opacity(
                opacity: backdropOpacity.clamp(0.15, 1.0),
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      Center(
                        child: GestureDetector(
                          onVerticalDragStart: _handleVerticalDragStart,
                          onVerticalDragUpdate: _handleVerticalDragUpdate,
                          onVerticalDragEnd: _handleVerticalDragEnd,
                          onDoubleTapDown: _handleDoubleTapDown,
                          onDoubleTap: _handleDoubleTap,
                          child: Hero(
                            tag: widget.heroTag,
                            flightShuttleBuilder: (
                              flightContext,
                              animation,
                              direction,
                              fromContext,
                              toContext,
                            ) {
                              final isPush = direction == HeroFlightDirection.push;
                              final beginRadius =
                                  isPush ? widget.sourceRadius : 0.0;
                              final endRadius =
                                  isPush ? 0.0 : widget.sourceRadius;
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, child) {
                                  final t = Curves.easeInOut.transform(
                                    animation.value,
                                  );
                                  final radius = lerpDouble(
                                    beginRadius,
                                    endRadius,
                                    t,
                                  )!;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      radius,
                                    ),
                                    child: child,
                                  );
                                },
                                child: _buildImage(),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.width,
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  minScale: 1.0,
                                  maxScale: 4.5,
                                  onInteractionStart: (_) {
                                    if (_transformController.value
                                            .getMaxScaleOnAxis() >
                                        1.01) {
                                      setState(() => _isZoomed = true);
                                    }
                                  },
                                  onInteractionEnd: (_) {
                                    final scale = _transformController.value
                                        .getMaxScaleOnAxis();
                                    if (scale <= 1.01 && _isZoomed) {
                                      setState(() => _isZoomed = false);
                                    }
                                  },
                                  child: _buildImage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Close (X) button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.black.withOpacity(0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _close,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
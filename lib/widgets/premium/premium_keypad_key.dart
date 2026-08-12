// lib/widgets/premium/premium_keypad_key.dart
//
// Shared numeric-keypad key for amount-entry screens (Investment
// Amount, Configure Investment amount step). Fixes two things every
// ad-hoc keypad in this app used to get wrong:
//
//   1. Touch target: a bare GestureDetector only registers taps on
//      its painted child (the digit glyph itself) unless
//      HitTestBehavior.opaque is set — so a user tapping slightly
//      beside the number could miss entirely. This widget always
//      hit-tests the full cell.
//   2. Feedback: adds a subtle premium press animation (scale down +
//      soft highlight) plus a short keypad tick sound and light
//      haptic on every tap, via [KeypadFeedback] — which already
//      prevents overlapping sounds on rapid taps and respects the
//      device's silent/vibrate switch and the app's sound toggle.
//
// Usage (drop-in replacement for a manual GestureDetector + Container
// key cell):
//
//   PremiumKeypadKey(
//     onTap: () => _onKeyTap('7'),
//     child: Text('7', style: ...),
//   )
//
//   PremiumKeypadKey(
//     onTap: () => _onKeyTap('back'),
//     isBackspace: true,
//     child: Icon(Icons.backspace_outlined),
//   )
//
// Pass onTap: null for an empty spacer cell (bottom-left corner) —
// it renders inert with no feedback.
import 'package:flutter/material.dart';
import '../../services/audio/keypad_sound_player.dart';

class PremiumKeypadKey extends StatefulWidget {
  const PremiumKeypadKey({
    super.key,
    required this.onTap,
    required this.child,
    this.isBackspace = false,
    this.height,
    this.highlightColor = const Color(0xFF9AE0BC),
  });

  /// The key's handler (digit entry / backspace logic already lives on
  /// the parent screen — this widget only adds touch-target size,
  /// animation, and sound/haptic feedback around it). Pass null for a
  /// non-interactive spacer cell.
  final VoidCallback? onTap;

  /// Digit text / backspace icon to render, unchanged.
  final Widget child;

  /// Whether this key plays the backspace cue instead of the digit
  /// tick when pressed.
  final bool isBackspace;

  /// Cell height. Defaults to a comfortably large 68 logical pixels —
  /// slightly taller than the 64px rows this replaces, so the target
  /// area is a touch more forgiving without visually crowding the pad.
  final double? height;

  /// Tint used for the soft press highlight.
  final Color highlightColor;

  @override
  State<PremiumKeypadKey> createState() => _PremiumKeypadKeyState();
}

class _PremiumKeypadKeyState extends State<PremiumKeypadKey> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null;

  void _setPressed(bool value) {
    if (!_interactive) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_interactive) return;
    if (widget.isBackspace) {
      KeypadFeedback.backspace();
    } else {
      KeypadFeedback.digit();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) {
      // Must still be Expanded so this spacer occupies the same flex
      // width as the other keys in the row — otherwise the row's
      // remaining two keys stretch to fill the freed space and every
      // column after the empty cell drifts out of alignment with the
      // rows above it (this was the root cause of the crooked keypad).
      return Expanded(
        child: SizedBox(height: widget.height ?? 68),
      );
    }
    return Expanded(
      child: GestureDetector(
        // Opaque: the whole cell is tappable, not just the glyph the
        // child paints — this is the actual touch-target fix.
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: widget.height ?? 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.highlightColor.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
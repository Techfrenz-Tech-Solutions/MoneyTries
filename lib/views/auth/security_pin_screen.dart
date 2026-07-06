import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';

// ── Palette (matches Moneytries theme) ───────────────────────────────────────
const _bgColor = Color(0xFFECEFF5);
const _brandGreen = Color(0xFF3D9E6A);
const _titleColor = Color(0xFF111827);
const _subtitleColor = Color(0xFF6B7280);
const _dotEmpty = Color(0xFFD1D5DB);
const _dotFilled = Color(0xFF3D9E6A);
const _keyBg = Color(0xFFFFFFFF);
const _keyText = Color(0xFF111827);
const _keyShadow = Color(0x14000000);
const _confirmBtnBg = Color(0xFFDCFCE7);
const _confirmBtnText = Color(0xFF6B7280);
const _confirmActive = Color(0xFF3D9E6A);
const _confirmActiveTx = Color(0xFFFFFFFF);
const _iconCircleBg = Color(0xFFFFFFFF);

class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key});

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _pin = [];
  static const int _pinLength = 4;

  // Shake animation controller
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(int digit) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin.add(digit));
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  void _onConfirm() async {
    if (_pin.length < _pinLength) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    // Save the PIN to SharedPreferences keyed by userId
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id') ?? '';
    final pinStr = _pin.join();
    await prefs.setString('app_pin_$userId', pinStr);

    if (!mounted) return;
    // Navigate to home after PIN is set
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final bool pinComplete = _pin.length == _pinLength;

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgColor,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 22,
                            color: _brandGreen,
                          ),
                        ),
                      ),
                      Text(
                        'Moneytries',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _brandGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Shield / lock icon circle ────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _iconCircleBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Filled dot (shield hint)
                      Positioned(
                        left: 22,
                        top: 32,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _brandGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Lock icon
                      const Positioned(
                        right: 20,
                        top: 28,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 22,
                          color: _brandGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'Set Your App PIN',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 8),

                // ── Subtitle ─────────────────────────────────────────────
                Text(
                  'You\'ll enter this 4-digit PIN\nevery time you open the app',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _subtitleColor,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                // ── 4 PIN dots ───────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final double offset = _shakeCtrl.isAnimating
                        ? 8 * (0.5 - _shakeAnim.value).abs() * 2
                        : 0;
                    return Transform.translate(
                      offset: Offset(
                        offset *
                            ((_shakeAnim.value * 10).toInt().isEven ? 1 : -1),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? _dotFilled : Colors.transparent,
                          border: Border.all(
                            color: filled ? _dotFilled : _dotEmpty,
                            width: 1.8,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Number pad ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _KeyRow(keys: const [1, 2, 3], onKey: _onKey),
                        const SizedBox(height: 12),
                        _KeyRow(keys: const [4, 5, 6], onKey: _onKey),
                        const SizedBox(height: 12),
                        _KeyRow(keys: const [7, 8, 9], onKey: _onKey),
                        const SizedBox(height: 12),
                        // Last row: empty slot, 0, backspace
                        Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _KeyButton(
                                child: Text(
                                  '0',
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: _keyText,
                                  ),
                                ),
                                onTap: () => _onKey(0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _KeyButton(
                                child: const Icon(
                                  Icons.backspace_outlined,
                                  size: 22,
                                  color: _keyText,
                                ),
                                onTap: _onDelete,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Confirm PIN button ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: pinComplete
                                  ? _confirmActive
                                  : _confirmBtnBg,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: _onConfirm,
                                child: Center(
                                  child: Text(
                                    'Confirm PIN',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: pinComplete
                                          ? _confirmActiveTx
                                          : _confirmBtnText,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── A row of 3 digit key buttons ──────────────────────────────────────────────
class _KeyRow extends StatelessWidget {
  final List<int> keys;
  final ValueChanged<int> onKey;

  const _KeyRow({required this.keys, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .expand(
            (k) => [
              Expanded(
                child: _KeyButton(
                  child: Text(
                    '$k',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: _keyText,
                    ),
                  ),
                  onTap: () => onKey(k),
                ),
              ),
              if (k != keys.last) const SizedBox(width: 12),
            ],
          )
          .toList(),
    );
  }
}

// ── Single key button ─────────────────────────────────────────────────────────
class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _KeyButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _keyBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _keyShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFDCFCE7),
          highlightColor: const Color(0xFFF0FDF4),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
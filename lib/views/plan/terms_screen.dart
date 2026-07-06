import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';

const _bgColor = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _brandGreen = Color(0xFF3D9E6A);
const _itemBorder = Color(0xFFE5E7EB);

const _heroGradient = LinearGradient(
  colors: [Color(0xFF3D9E6A), Color(0xFF86C9A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _heroShadowColor = Color(0xFF3D9E6A);

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  static const _terms = [
    (
      icon: Icons.account_balance_outlined,
      title: 'Capital Commitment',
      body:
          'Subscription to this tier requires a fixed monthly investment amount as defined in your chosen plan structure.',
    ),
    (
      icon: Icons.calendar_today_outlined,
      title: 'Sequential Processing',
      body:
          'To maintain portfolio balance, only one capital injection/payment is permitted per 30-day billing cycle.',
    ),
    (
      icon: Icons.lock_outline_rounded,
      title: 'Fixed Mandate',
      body:
          'Your committed investment amount cannot be altered once the engagement protocol is initiated.',
    ),
    (
      icon: Icons.water_drop_outlined,
      title: 'ROI Liquidity',
      body:
          'Accrued earnings are fully liquid and may be withdrawn at any available redemption window without restriction.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Principal Security',
      body:
          'Your invested principal is secured under institutional custodianship and governed by compliance protocols.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {'title': '6 Month Plan', 'rate': '0.35%', 'months': 6};

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: _titleDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Moneytries',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Terms of\nEngagement',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: _titleDark,
                          height: 1.15,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Please review our structural investment\nprotocols before proceeding. These\nmandates ensure the institutional stability\nof your wealth management journey.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _subtitleGrey,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Hero card ────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: _heroGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _heroShadowColor.withOpacity(0.30),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: _white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Secure Asset\nGovernance',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Institutional Grade Compliance',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: _white.withOpacity(0.80),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Terms list card ────────────────────────────────
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: List.generate(_terms.length, (i) {
                            final t = _terms[i];
                            final isLast = i == _terms.length - 1;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    20,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        t.icon,
                                        size: 22,
                                        color: _brandGreen,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: _titleDark,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              t.body,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: _subtitleGrey,
                                                height: 1.55,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: _itemBorder,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── Bottom area ────────────────────────────────────────────
              Container(
                color: _bgColor,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _accepted = !_accepted),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _accepted,
                              onChanged: (v) =>
                                  setState(() => _accepted = v ?? false),
                              activeColor: _brandGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I hereby acknowledge that I have read, understood, and agreed to the structural investment protocols outlined above.',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: _titleDark,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Accept & Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _accepted
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _heroGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _heroShadowColor.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.configure,
                                  arguments: args,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Accept & Continue',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _white,
                                  ),
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: const Color(
                                  0xFFD1D5DB,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Accept & Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _white,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';

const _bgColor = Color(0xFFF7F5F2);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _brandGreen = Color(0xFF1F6B45); // banner dark green
const _itemBorder = Color(0xFFE8E4DE);

const _heroGradient = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _heroShadowColor = Color(0xFF9AE0BC);

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
          'Subscription to this tier requires a single, fixed one-time investment amount as defined in your chosen plan structure.',
    ),
    (
      icon: Icons.calendar_today_outlined,
      title: 'Single Payment',
      body:
          'Your investment is funded by exactly one payment, made at the start of the plan and reviewed once by our admin team.',
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
          'Your invested principal stays locked for the full tenure of the plan and is automatically credited back to your wallet on maturity.',
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
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: _titleDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Moneytries',
                      style: TextStyle(
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontSize: 17.sp,
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
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 8.h),
                      Text(
                        'Terms of\nEngagement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 34.sp,
                          fontWeight: FontWeight.w800,
                          color: _titleDark,
                          height: 1.15,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        'Please review our structural investment\nprotocols before proceeding. These\nmandates ensure the institutional stability\nof your wealth management journey.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: _subtitleGrey,
                          height: 1.65,
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // ── Hero card ────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          gradient: _heroGradient,
                          borderRadius: BorderRadius.circular(20.r),
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
                              width: 44.w,
                              height: 44.h,
                              decoration: BoxDecoration(
                                color: _brandGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.verified_user_outlined,
                                color: _brandGreen,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Secure Asset\nGovernance',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                color: _titleDark,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Institutional Grade Compliance',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                color: _brandGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // ── Terms list card ────────────────────────────────
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(20.r),
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
                                  padding: EdgeInsets.fromLTRB(
                                    20.w,
                                    20.h,
                                    20.w,
                                    20.h,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        t.icon,
                                        size: 22.sp,
                                        color: _brandGreen,
                                      ),
                                      SizedBox(width: 14.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.title,
                                              style: TextStyle(
                                                fontFamily: GoogleFonts.inter().fontFamily,
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w700,
                                                color: _titleDark,
                                              ),
                                            ),
                                            SizedBox(height: 5.h),
                                            Text(
                                              t.body,
                                              style: TextStyle(
                                                fontFamily: GoogleFonts.inter().fontFamily,
                                                fontSize: 13.sp,
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
                                  Divider(
                                    height: 1.h,
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
                      SizedBox(height: 28.h),
                    ],
                  ),
                ),
              ),

              // ── Bottom area ────────────────────────────────────────────
              Container(
                color: _bgColor,
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _accepted = !_accepted),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22.w,
                            height: 22.h,
                            child: Checkbox(
                              value: _accepted,
                              onChanged: (v) =>
                                  setState(() => _accepted = v ?? false),
                              activeColor: _brandGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              side: BorderSide(
                                color: Color(0xFFD9D5CF),
                                width: 1.5.r,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'I hereby acknowledge that I have read, understood, and agreed to the structural investment protocols outlined above.',
                              style: TextStyle(
                                fontFamily: GoogleFonts.inter().fontFamily,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w400,
                                color: _titleDark,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Accept & Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: _accepted
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _heroGradient,
                                borderRadius: BorderRadius.circular(16.r),
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
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Accept & Continue',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.inter().fontFamily,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _brandGreen,
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
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Accept & Continue',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                  fontSize: 16.sp,
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

// lib/views/legal/legal_document_screen.dart
//
// Premium, scrollable Terms of Service / Privacy Policy viewer.
// Opened as a modal bottom sheet from the Sign Up screen so the user can
// read the full document and return to Sign Up without losing any of the
// data they've already entered (the sheet floats above the existing
// screen — nothing underneath is rebuilt or popped).

import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

// ── Palette — light green / light brown / white / beige ───────────────────
const _legalSheetBg   = Color(0xFFFFFFFF);
const _legalBg        = Color(0xFFFAF6EF); // beige
const _legalCard      = Color(0xFFFFFFFF);
const _legalGreen     = Color(0xFF4CAF7D); // light/brand green
const _legalGreenSoft = Color(0xFFE7F5EC); // light green tint
const _legalBrown     = Color(0xFF8C6E4B); // light brown
const _legalBrownSoft = Color(0xFFF3E9D8); // light brown / beige tint
const _legalDivider   = Color(0xFFEDE4D3);
const _legalTitle     = Color(0xFF3B2F22); // warm dark brown for headings
const _legalBody      = Color(0xFF5B5147); // warm gray-brown body text
const _legalHandle    = Color(0xFFE2D6BE);

enum LegalDocType { termsOfService, privacyPolicy }

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

class _LegalDocument {
  final String title;
  final IconData icon;
  final String lastUpdated;
  final String intro;
  final List<_LegalSection> sections;
  const _LegalDocument({
    required this.title,
    required this.icon,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });
}

const _termsDocument = _LegalDocument(
  title: 'Terms of Service',
  icon: Icons.description_outlined,
  lastUpdated: 'Last updated: 1 July 2026',
  intro:
      'Welcome to Moneytries. These Terms of Service ("Terms") govern your '
      'access to and use of the Moneytries mobile application, website, and '
      'related services (together, the "Services"). By creating an account '
      'or otherwise using the Services, you agree to be bound by these '
      'Terms. Please read them carefully before you continue.',
  sections: [
    _LegalSection(
      '1. Eligibility',
      'You must be at least 18 years old and capable of entering into a '
          'legally binding agreement to use the Services. By registering, '
          'you confirm that all information you provide — including your '
          'name, contact details, and identity documents — is accurate, '
          'current, and complete, and that you will keep it updated.',
    ),
    _LegalSection(
      '2. Your Account',
      'You are responsible for maintaining the confidentiality of your '
          'login credentials, app PIN, and any device used to access your '
          'account, and for all activity that occurs under your account. '
          'Notify us immediately if you suspect any unauthorized access or '
          'security breach.',
    ),
    _LegalSection(
      '3. Identity Verification (KYC)',
      'To comply with applicable know-your-customer and anti-money-'
          'laundering regulations, we may require you to submit identity, '
          'address, or financial documents before you can deposit, invest, '
          'or withdraw funds. We may suspend or restrict your account until '
          'verification is complete or if verification cannot be confirmed.',
    ),
    _LegalSection(
      '4. Investment Plans and Returns',
      'The Services allow you to select and fund investment plans as '
          'described in the app. Projected returns, maturity dates, and '
          'schedules shown in the app are estimates based on the plan terms '
          'in effect at the time of purchase and are not guaranteed unless '
          'expressly stated. All investments carry risk, including the risk '
          'of loss of principal; past performance is not indicative of '
          'future results.',
    ),
    _LegalSection(
      '5. Deposits, Withdrawals, and Fees',
      'Deposits and withdrawals are processed through the payment methods '
          'made available in the app. Processing times may vary depending '
          'on your bank or payment provider. Applicable fees, if any, will '
          'be disclosed in the app before you confirm a transaction. You '
          'are responsible for any third-party charges levied by your bank '
          'or payment provider.',
    ),
    _LegalSection(
      '6. Referral Program',
      'Where a referral program is offered, referral rewards are credited '
          'in accordance with the program rules displayed in the app, and '
          'are subject to the referred user completing the qualifying '
          'action (such as their first funded plan). We may modify, '
          'suspend, or end the referral program, or decline rewards '
          'obtained through abuse or fraudulent activity, at any time.',
    ),
    _LegalSection(
      '7. Prohibited Activities',
      'You agree not to misuse the Services, including by attempting to '
          'circumvent verification requirements, using the Services for '
          'money laundering or fraud, interfering with the normal operation '
          'of the app, or accessing accounts that are not your own.',
    ),
    _LegalSection(
      '8. Suspension and Termination',
      'We may suspend or terminate your access to the Services if you '
          'breach these Terms, if required by law or a regulator, or to '
          'protect the security or integrity of the Services. You may close '
          'your account at any time by contacting support, subject to the '
          'completion of any pending plans or transactions.',
    ),
    _LegalSection(
      '9. Disclaimers',
      'The Services are provided on an "as is" and "as available" basis. '
          'To the fullest extent permitted by law, we disclaim all '
          'warranties, express or implied, regarding the Services, '
          'including accuracy, reliability, or fitness for a particular '
          'purpose.',
    ),
    _LegalSection(
      '10. Limitation of Liability',
      'To the extent permitted by law, Moneytries and its affiliates will '
          'not be liable for indirect, incidental, or consequential damages '
          'arising from your use of the Services, except where such '
          'limitation is not permitted by applicable law.',
    ),
    _LegalSection(
      '11. Changes to These Terms',
      'We may update these Terms from time to time to reflect changes in '
          'our Services or legal requirements. Material changes will be '
          'notified in the app. Continued use of the Services after changes '
          'take effect constitutes acceptance of the revised Terms.',
    ),
    _LegalSection(
      '12. Governing Law',
      'These Terms are governed by the laws of India, without regard to '
          'conflict-of-law principles, and any disputes will be subject to '
          'the exclusive jurisdiction of the competent courts.',
    ),
    _LegalSection(
      '13. Contact Us',
      'If you have questions about these Terms, please reach out through '
          'the Help & Support section in the app.',
    ),
  ],
);

const _privacyDocument = _LegalDocument(
  title: 'Privacy Policy',
  icon: Icons.privacy_tip_outlined,
  lastUpdated: 'Last updated: 1 July 2026',
  intro:
      'This Privacy Policy explains how Moneytries collects, uses, shares, '
      'and protects your personal information when you use our mobile '
      'application and related services. By using the Services, you '
      'consent to the practices described in this Policy.',
  sections: [
    _LegalSection(
      '1. Information We Collect',
      'We collect information you provide directly, such as your name, '
          'email address, phone number, password, and referral code during '
          'registration; identity and address documents for KYC '
          'verification; and payment details when you deposit or withdraw '
          'funds. We also collect information automatically, such as '
          'device identifiers, app usage, and login activity.',
    ),
    _LegalSection(
      '2. How We Use Your Information',
      'We use your information to create and manage your account, verify '
          'your identity, process transactions and investment plans, '
          'provide customer support, send OTPs and important account '
          'notifications, detect and prevent fraud, and improve the '
          'Services.',
    ),
    _LegalSection(
      '3. Biometrics and Device Security',
      'If you enable biometric login or an app PIN, biometric data is '
          'processed and matched by your device\'s operating system — we do '
          'not receive or store raw biometric data on our servers. We only '
          'receive confirmation that your device successfully verified you.',
    ),
    _LegalSection(
      '4. Sharing Your Information',
      'We do not sell your personal information. We may share it with '
          'service providers who help us operate the Services (such as '
          'payment processors, SMS/email delivery providers, and cloud '
          'hosting), with regulators or law enforcement where required by '
          'law, and in connection with a merger, acquisition, or sale of '
          'assets, subject to confidentiality obligations.',
    ),
    _LegalSection(
      '5. Data Security',
      'We use technical and organizational safeguards — including '
          'encryption in transit, access controls, and session tracking '
          'across your devices — designed to protect your information from '
          'unauthorized access, alteration, or disclosure. No method of '
          'transmission or storage is completely secure, and we cannot '
          'guarantee absolute security.',
    ),
    _LegalSection(
      '6. Data Retention',
      'We retain your information for as long as your account is active '
          'and as needed to comply with legal, tax, and regulatory record-'
          'keeping obligations, resolve disputes, and enforce our '
          'agreements.',
    ),
    _LegalSection(
      '7. Your Rights and Choices',
      'You may access, update, or correct your profile information within '
          'the app at any time. You may request account closure or deletion '
          'of your personal information, subject to our legal and '
          'regulatory retention obligations, by contacting support.',
    ),
    _LegalSection(
      '8. Children\'s Privacy',
      'The Services are not directed to individuals under the age of 18, '
          'and we do not knowingly collect personal information from '
          'minors.',
    ),
    _LegalSection(
      '9. Changes to This Policy',
      'We may update this Privacy Policy from time to time. Material '
          'changes will be notified in the app, and the "Last updated" date '
          'above will reflect the most recent revision.',
    ),
    _LegalSection(
      '10. Contact Us',
      'If you have questions about this Privacy Policy or how your '
          'information is handled, please reach out through the Help & '
          'Support section in the app.',
    ),
  ],
);

/// Opens the premium, scrollable legal document viewer as a modal bottom
/// sheet. The caller (Sign Up screen) stays mounted underneath, so all
/// entered field values are preserved while the user reads and after they
/// dismiss the sheet.
Future<void> showLegalDocumentSheet(BuildContext context, LegalDocType type) {
  final doc = type == LegalDocType.termsOfService
      ? _termsDocument
      : _privacyDocument;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _LegalDocumentSheet(doc: doc),
  );
}

class _LegalDocumentSheet extends StatelessWidget {
  final _LegalDocument doc;
  const _LegalDocumentSheet({required this.doc});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _legalSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              // Drag handle
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _legalHandle,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 14.h),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.h,
                      decoration: BoxDecoration(
                        color: _legalGreenSoft,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: _legalGreen.withOpacity(0.25)),
                      ),
                      child: Icon(doc.icon, color: _legalGreen, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w700,
                              color: _legalTitle,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            doc.lastUpdated,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 12.sp,
                              color: _legalBrown,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34.w,
                        height: 34.h,
                        decoration: BoxDecoration(
                          color: _legalBrownSoft,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 19.sp, color: _legalBrown),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Divider(color: _legalDivider, height: 1.h, thickness: 1),
              // Scrollable content
              Expanded(
                child: Container(
                  color: _legalBg,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 28.h),
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: _legalCard,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: _legalDivider),
                        ),
                        child: Text(
                          doc.intro,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 14.sp,
                            height: 1.6,
                            color: _legalBody,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      for (final section in doc.sections) ...[
                        _LegalSectionCard(section: section),
                        SizedBox(height: 14.h),
                      ],
                      SizedBox(height: 6.h),
                    ],
                  ),
                ),
              ),
              // Footer — return to Sign Up without losing any entered data
              Container(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                decoration: BoxDecoration(
                  color: _legalSheetBg,
                  border: Border(top: BorderSide(color: _legalDivider)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _legalGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Back to Sign Up',
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  final _LegalSection section;
  const _LegalSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _legalCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _legalDivider),
        boxShadow: [
          BoxShadow(
            color: _legalBrown.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: _legalGreen,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  section.heading,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _legalTitle,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            section.body,
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 13.5.sp,
              height: 1.6,
              color: _legalBody,
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bg           = Color(0xFFECEFF5);
const _surfaceCard  = Color(0xFFFFFFFF);
const _primaryGreen = Color(0xFF3D9E6A);
const _mintTitle    = Color(0xFF2D7A52);
const _bodyGrey     = Color(0xFF6B7280);
const _mutedGrey    = Color(0xFF9CA3AF);
const _divider      = Color(0xFFD1EAD9);
const _errorRed     = Color(0xFFDC2626);

const String _kBaseUrl      = 'http://192.168.0.17:3000';
const String _supportEmail  = 'manikandan.455.t@gmail.com';
const String _supportPhone  = '9080706050';

// ─────────────────────────────────────────────────────────────────────────────
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  int? _expandedFaq;

  static const _faqs = [
    _Faq('How do I withdraw my earnings?',
        'Go to Home → Withdraw, enter the amount, and confirm with your security PIN. Withdrawals are processed within 24 hours to your linked bank account.'),
    _Faq('What is the minimum deposit amount?',
        'The minimum deposit is ₹500. There is no upper limit. Deposits reflect in your wallet instantly after payment confirmation.'),
    _Faq('Is my capital safe?',
        'Yes. Moneytries uses bank-grade encryption and follows strict fund segregation policies to ensure your capital is always protected.'),
    _Faq('How does the referral program work?',
        'Share your unique referral code. When your friend deposits and activates a plan, you earn 0.10% ROI on their investment as a bonus.'),
    _Faq('What are the KYC requirements?',
        'You need a valid government-issued photo ID (Aadhaar or PAN) and a selfie. KYC is completed within 2 working hours.'),
    _Faq('How long do deposits take?',
        'Deposits via UPI and Net Banking are instant. NEFT/RTGS transfers may take up to 2 hours during banking hours.'),
    _Faq('How can I request a refund?',
        'Raise a ticket from the Support page and select "Refund Request". Our team will review and process it within 3–5 business days.'),
    _Faq('What if my transaction fails?',
        'If money is debited but the transaction shows failed, it will be auto-reversed within 48 hours. You can also raise a support ticket for faster resolution.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bg),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        _buildHeroSection(),
                        const SizedBox(height: 28),
                        _buildContactGrid(),
                        const SizedBox(height: 32),
                        _buildFaqSection(),
                        const SizedBox(height: 24),
                        _buildFooterLine(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF111827)),
          ),
          const SizedBox(width: 14),
          Text('Help & Support',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D9E6A), Color(0xFF2D7A52)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How can we help?',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Our support team is always here for you.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withOpacity(0.85))),
          ],
        ),
      ),
    );
  }

  // ── 2×2 grid ─────────────────────────────────────────────────────────────
  Widget _buildContactGrid() {
    final cards = [
      _CardDef(Icons.chat_bubble_outline_rounded, 'Live Chat',     'Instant Response',   _onLiveChat),
      _CardDef(Icons.phone_outlined,              'Priority Call', '24/7 Dedicated Line',_onPriorityCall),
      _CardDef(Icons.mail_outline_rounded,        'Email',         'Official Support',   _onEmail),
      _CardDef(Icons.confirmation_number_outlined,'Ticket',        'Track Tickets',      _onTicket),
    ];

    // Content-sized rows (IntrinsicHeight) instead of a fixed
    // childAspectRatio grid, so each card grows to fit its own text
    // (longer labels, larger system font/accessibility scale, or a
    // narrower screen causing wrap) instead of overflowing when the
    // device doesn't match the aspect ratio the layout was designed for.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCard(cards[0])),
                const SizedBox(width: 14),
                Expanded(child: _buildCard(cards[1])),
              ],
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCard(cards[2])),
                const SizedBox(width: 14),
                Expanded(child: _buildCard(cards[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_CardDef c) {
    return GestureDetector(
      onTap: c.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _divider, width: 1),
          boxShadow: [
            BoxShadow(color: _primaryGreen.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon, size: 22, color: _mintTitle),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                const SizedBox(height: 3),
                Text(c.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: _mintTitle)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Card tap handlers ─────────────────────────────────────────────────────

  void _onLiveChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComingSoonSheet(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Live Chat',
        message: 'Live chat support is coming soon!\nWe\'re working hard to bring you instant support.',
      ),
    );
  }

  void _onPriorityCall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _PriorityCallSheet(),
    );
  }

  void _onEmail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _EmailSupportSheet(),
    );
  }

  void _onTicket() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _TicketSheet(),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────
  Widget _buildFaqSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FAQs', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          const SizedBox(height: 14),
          ...List.generate(_faqs.length, (i) {
            final isExpanded = _expandedFaq == i;
            return _buildFaqItem(i, isExpanded);
          }),
        ],
      ),
    );
  }

  Widget _buildFaqItem(int i, bool expanded) {
    return GestureDetector(
      onTap: () => setState(() => _expandedFaq = expanded ? null : i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: expanded ? _primaryGreen.withOpacity(0.4) : _divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(_faqs[i].q,
                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF111827)))),
              Icon(expanded ? Icons.remove_rounded : Icons.add_rounded, size: 18, color: _primaryGreen),
            ]),
            if (expanded) ...{
              const SizedBox(height: 10),
              Text(_faqs[i].a,
                style: GoogleFonts.poppins(fontSize: 13, color: _bodyGrey, height: 1.6)),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Text('Moneytries Support · Available 24/7',
          style: GoogleFonts.poppins(fontSize: 12, color: _mutedGrey)),
      ),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.trending_up_rounded, 'Plans'),
      _NavItem(Icons.history_rounded, 'History'),
      _NavItem(Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _surfaceCard,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: List.generate(navItems.length, (i) {
          const color = _mutedGrey;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                switch (i) {
                  case 0: Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false); break;
                  case 1: Navigator.pushNamed(context, AppRoutes.plan); break;
                  case 2: Navigator.pushNamed(context, AppRoutes.history); break;
                  case 3: Navigator.pushNamed(context, AppRoutes.profile); break;
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Icon(navItems[i].icon, size: 22, color: color),
                  const SizedBox(height: 3),
                  Text(navItems[i].label,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.4)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COMING SOON SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _ComingSoonSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _ComingSoonSheet({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: _mintTitle),
          ),
          const SizedBox(height: 20),
          Text(title,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF856404)),
                const SizedBox(width: 6),
                Text('Coming Soon',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF856404))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: _bodyGrey, height: 1.6)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Got it', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRIORITY CALL SHEET  — uses url_launcher to open the phone dialpad
// ═════════════════════════════════════════════════════════════════════════════
class _PriorityCallSheet extends StatelessWidget {
  const _PriorityCallSheet();

  /// Opens the native phone dialpad pre-filled with the support number.
  Future<void> _launchDialer(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: copy number to clipboard
      await Clipboard.setData(const ClipboardData(text: _supportPhone));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open dialer. Number copied to clipboard.'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          // Green phone circle
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D9E6A), Color(0xFF2D7A52)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _primaryGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.phone_rounded, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('Priority Support Line',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('24/7 Dedicated Support',
            style: GoogleFonts.poppins(fontSize: 13, color: _bodyGrey)),
          const SizedBox(height: 28),
          // Number display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider, width: 1.5),
            ),
            child: Column(children: [
              Text('Support Number',
                style: GoogleFonts.poppins(fontSize: 12, color: _bodyGrey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(_supportPhone,
                style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w700, color: _mintTitle,
                  letterSpacing: 4,
                )),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Tap "Call Now" to open your phone dialpad',
            style: GoogleFonts.poppins(fontSize: 12, color: _mutedGrey)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mintTitle,
                  side: const BorderSide(color: _divider, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: _supportPhone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Number copied!'), backgroundColor: _primaryGreen),
                  );
                },
                child: Text('Copy', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.dialpad_rounded, size: 20),
                label: Text('Call Now', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                // ✅ Uses url_launcher — opens native phone dialpad
                onPressed: () => _launchDialer(context),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMAIL SUPPORT SHEET — sends email via backend API (user's login email as sender)
// ═════════════════════════════════════════════════════════════════════════════
class _EmailSupportSheet extends StatefulWidget {
  const _EmailSupportSheet();
  @override
  State<_EmailSupportSheet> createState() => _EmailSupportSheetState();
}

class _EmailSupportSheetState extends State<_EmailSupportSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  bool _sending = false;
  bool _sent    = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Calls POST /api/support/email
  /// Backend will use the user's stored email as "from" and send to _supportEmail.
  Future<void> _send() async {
    final subject = _subjectCtrl.text.trim();
    final body    = _bodyCtrl.text.trim();

    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both subject and message.'), backgroundColor: _errorRed),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');

      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/support/email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'subject': subject, 'message': body}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() { _sending = false; _sent = true; });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email sent successfully!'), backgroundColor: _primaryGreen),
          );
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to send email');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: _errorRed),
        );
      }
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets.bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.mail_outline_rounded, size: 24, color: _mintTitle),
            ),
            const SizedBox(width: 14),
            Text('Email Support', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          ]),
          const SizedBox(height: 8),
          // Info chip — user's email will be used as sender
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _divider),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: _mintTitle),
              const SizedBox(width: 6),
              Text('Sent from your registered email address',
                style: GoogleFonts.poppins(fontSize: 11, color: _mintTitle)),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Subject', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          _buildTextField(_subjectCtrl, 'e.g. Issue with my deposit', maxLines: 1),
          const SizedBox(height: 16),
          Text('Message', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          _buildTextField(_bodyCtrl, 'Describe your issue in detail...', maxLines: 5),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : _sent
                      ? const Icon(Icons.check_rounded, size: 18)
                      : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _sending ? 'Sending...' : _sent ? 'Sent!' : 'Submit',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _sent ? _mintTitle : _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: (_sending || _sent) ? null : _send,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: _mutedGrey),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryGreen, width: 1.5)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TICKET SHEET — Create + View tickets with replies + user follow-up reply
// ═════════════════════════════════════════════════════════════════════════════
class _TicketSheet extends StatefulWidget {
  const _TicketSheet();
  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

enum _TicketView { list, create, detail }

class _TicketSheetState extends State<_TicketSheet> {
  _TicketView _view = _TicketView.list;

  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _ticketReplies = [];

  final _issueCtrl       = TextEditingController();
  final _subjectCtrl     = TextEditingController();
  final _userReplyCtrl   = TextEditingController();
  final _scrollCtrl      = ScrollController();

  bool _loading    = false;
  bool _submitting = false;
  bool _replying   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _issueCtrl.dispose();
    _subjectCtrl.dispose();
    _userReplyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadTickets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final res = await http.get(
        Uri.parse('$_kBaseUrl/api/support/tickets'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body   = jsonDecode(res.body);
        final inner  = body['data'] ?? body;
        setState(() => _tickets = List<Map<String, dynamic>>.from(inner['tickets'] ?? []));
      } else {
        setState(() => _tickets = []);
      }
    } catch (_) {
      setState(() { _tickets = []; _error = null; });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitTicket() async {
    final subject = _subjectCtrl.text.trim();
    final issue   = _issueCtrl.text.trim();
    if (subject.isEmpty || issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and issue.'), backgroundColor: _errorRed),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/support/tickets'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'subject': subject, 'message': issue}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _subjectCtrl.clear();
        _issueCtrl.clear();
        setState(() => _view = _TicketView.list);
        await _loadTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket submitted! We\'ll respond soon.'), backgroundColor: _primaryGreen),
          );
        }
      } else {
        throw Exception('Failed to submit');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: _errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadTicketDetail(Map<String, dynamic> ticket) async {
    setState(() { _selectedTicket = ticket; _view = _TicketView.detail; _loading = true; _ticketReplies = []; });
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final id = ticket['id'] ?? ticket['_id'];
      final res = await http.get(
        Uri.parse('$_kBaseUrl/api/support/tickets/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body);
        final inner = body['data'] ?? body;
        setState(() {
          _selectedTicket = Map<String, dynamic>.from(inner['ticket'] ?? ticket);
          _ticketReplies  = List<Map<String, dynamic>>.from(inner['replies'] ?? inner['messages'] ?? []);
        });
      }
    } catch (_) {
      // keep current ticket data
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// User sends a follow-up reply on their ticket
  Future<void> _sendUserReply() async {
    final message = _userReplyCtrl.text.trim();
    if (message.isEmpty) return;

    final ticket = _selectedTicket;
    if (ticket == null) return;
    final id = ticket['id'] ?? ticket['_id'];

    setState(() => _replying = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');

      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/support/tickets/$id/reply'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        _userReplyCtrl.clear();
        // Reload full detail to get updated replies
        await _loadTicketDetail(ticket);
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to send reply');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: _errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(0, 0, 0, insets.bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSheetHandle(),
          _buildSheetHeader(),
          const Divider(height: 1, color: _divider),
          Flexible(child: _buildSheetBody()),
        ],
      ),
    );
  }

  Widget _buildSheetHandle() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Center(child: Container(width: 40, height: 4,
      decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
  );

  Widget _buildSheetHeader() {
    String title;
    Widget? leading;
    switch (_view) {
      case _TicketView.list:
        title = 'Support Tickets';
        leading = null;
        break;
      case _TicketView.create:
        title = 'New Ticket';
        leading = IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF111827)),
          onPressed: () => setState(() => _view = _TicketView.list),
        );
        break;
      case _TicketView.detail:
        final rawId = (_selectedTicket?['id'] ?? _selectedTicket?['_id'] ?? '').toString();
        final shortId = rawId.length >= 6 ? rawId.substring(0, 6).toUpperCase() : rawId.toUpperCase();
        title = 'Ticket #$shortId';
        leading = IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF111827)),
          onPressed: () => setState(() => _view = _TicketView.list),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(children: [
        leading ?? const SizedBox(width: 48),
        Expanded(
          child: Text(title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
        ),
        if (_view == _TicketView.list)
          GestureDetector(
            onTap: () => setState(() => _view = _TicketView.create),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(20)),
              child: Text('+ New', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          )
        else if (_view == _TicketView.detail)
          GestureDetector(
            onTap: () => _loadTicketDetail(_selectedTicket!),
            child: const Icon(Icons.refresh_rounded, size: 20, color: _bodyGrey),
          )
        else
          const SizedBox(width: 48),
      ]),
    );
  }

  Widget _buildSheetBody() {
    switch (_view) {
      case _TicketView.list:   return _buildTicketList();
      case _TicketView.create: return _buildCreateTicket();
      case _TicketView.detail: return _buildTicketDetail();
    }
  }

  // ── Ticket list ───────────────────────────────────────────────────────────
  Widget _buildTicketList() {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _primaryGreen)));

    if (_tickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.confirmation_number_outlined, size: 56, color: _mutedGrey),
          const SizedBox(height: 16),
          Text('No tickets yet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('Tap "+ New" to raise a support ticket', style: GoogleFonts.poppins(fontSize: 13, color: _bodyGrey), textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildTicketCard(_tickets[i]),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status   = (ticket['status'] ?? 'open').toString().toLowerCase();
    final subject  = ticket['subject'] ?? ticket['title'] ?? 'Support Ticket';
    final message  = ticket['message'] ?? ticket['description'] ?? '';
    final replyCount = ticket['reply_count'];
    final hasAdminReply = replyCount != null && (replyCount is int ? replyCount > 0 : int.tryParse(replyCount.toString()) != null && int.parse(replyCount.toString()) > 0);
    final createdAt = ticket['created_at'] ?? ticket['createdAt'] ?? '';

    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (status) {
      case 'closed':
        statusColor = const Color(0xFF6B7280); statusBg = const Color(0xFFF3F4F6); statusLabel = 'Closed'; break;
      case 'resolved':
        statusColor = _mintTitle; statusBg = const Color(0xFFDCFCE7); statusLabel = 'Resolved'; break;
      case 'in_progress':
        statusColor = const Color(0xFF1D4ED8); statusBg = const Color(0xFFDBEAFE); statusLabel = 'In Progress'; break;
      default:
        statusColor = const Color(0xFFB45309); statusBg = const Color(0xFFFEF3C7); statusLabel = 'Open'; break;
    }

    return GestureDetector(
      onTap: () => _loadTicketDetail(ticket),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasAdminReply ? const Color(0xFFBBF7D0) : _divider, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(subject, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111827)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ]),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, color: _bodyGrey, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (hasAdminReply) ...[
              const Icon(Icons.reply_rounded, size: 14, color: _primaryGreen),
              const SizedBox(width: 4),
              Text('Admin replied', style: GoogleFonts.poppins(fontSize: 11, color: _primaryGreen, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            if (createdAt.toString().isNotEmpty)
              Text(_formatDate(createdAt.toString()),
                style: GoogleFonts.poppins(fontSize: 11, color: _mutedGrey)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _mutedGrey),
          ]),
        ]),
      ),
    );
  }

  // ── Create ticket ─────────────────────────────────────────────────────────
  Widget _buildCreateTicket() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Subject', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        _ticketField(_subjectCtrl, 'e.g. Withdrawal issue', maxLines: 1),
        const SizedBox(height: 16),
        Text('Describe your issue', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        _ticketField(_issueCtrl, 'Please describe the problem in detail so we can help you faster...', maxLines: 6),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _submitting ? null : _submitTicket,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Submit Ticket', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('Our team typically responds within 24 hours',
          style: GoogleFonts.poppins(fontSize: 12, color: _mutedGrey))),
      ]),
    );
  }

  Widget _ticketField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: _mutedGrey),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryGreen, width: 1.5)),
      ),
    );
  }

  // ── Ticket detail + replies + user reply box ──────────────────────────────
  Widget _buildTicketDetail() {
    final ticket    = _selectedTicket!;
    final subject   = ticket['subject'] ?? ticket['title'] ?? 'Support Ticket';
    final message   = ticket['message'] ?? ticket['description'] ?? '';
    final status    = (ticket['status'] ?? 'open').toString().toLowerCase();
    final createdAt = ticket['created_at'] ?? ticket['createdAt'] ?? '';
    final isClosed  = status == 'closed';

    return Column(
      children: [
        // Scrollable conversation
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Original ticket bubble (user)
              _buildMessageBubble(
                isAdmin: false,
                senderName: 'You',
                message: message,
                date: createdAt.toString(),
                subject: subject,
                status: status,
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: _primaryGreen)),
                )
              else if (_ticketReplies.isEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(children: [
                    const Icon(Icons.hourglass_top_rounded, size: 36, color: _mutedGrey),
                    const SizedBox(height: 8),
                    Text('Awaiting response from our team',
                      style: GoogleFonts.poppins(fontSize: 13, color: _bodyGrey)),
                  ]),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Conversation',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                ),
                ..._ticketReplies.map((reply) => _buildReplyBubble(reply)),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),

        // ── User reply input (hidden if ticket is closed) ──────────────────
        if (!isClosed) ...[
          const Divider(height: 1, color: _divider),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: Colors.white,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _userReplyCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF111827)),
                  decoration: InputDecoration(
                    hintText: 'Add a follow-up message...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: _mutedGrey),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryGreen, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _replying ? null : _sendUserReply,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _replying ? _mutedGrey : _primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _replying
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ] else ...[
          const Divider(height: 1, color: _divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text('This ticket is closed',
                style: GoogleFonts.poppins(fontSize: 12, color: _mutedGrey)),
            ),
          ),
        ],
      ],
    );
  }

  /// Original ticket message (user's own)
  Widget _buildMessageBubble({
    required bool isAdmin,
    required String senderName,
    required String message,
    required String date,
    String? subject,
    String? status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, size: 20, color: _mintTitle),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(senderName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
            if (date.isNotEmpty)
              Text(_formatDate(date), style: GoogleFonts.poppins(fontSize: 11, color: _mutedGrey)),
          ]),
          const Spacer(),
          if (status != null) _StatusBadge(status),
        ]),
        if (subject != null) ...[
          const SizedBox(height: 12),
          Text(subject, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
        ],
        const SizedBox(height: 6),
        Text(message, style: GoogleFonts.poppins(fontSize: 13.5, color: _bodyGrey, height: 1.6)),
      ]),
    );
  }

  Widget _buildReplyBubble(Map<String, dynamic> reply) {
    final isAdmin  = (reply['sender_type'] ?? reply['role'] ?? 'admin').toString().toLowerCase() == 'admin';
    final message  = reply['message'] ?? reply['content'] ?? '';
    final date     = reply['created_at'] ?? reply['createdAt'] ?? '';
    final name     = reply['sender_name'] ?? (isAdmin ? 'Support Team' : 'You');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAdmin ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isAdmin ? const Color(0xFFBBF7D0) : _divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isAdmin ? _primaryGreen.withOpacity(0.15) : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAdmin ? Icons.support_agent_rounded : Icons.person_outline_rounded,
                size: 17, color: isAdmin ? _mintTitle : _bodyGrey,
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAdmin ? 'Support Team' : name,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isAdmin ? _mintTitle : const Color(0xFF111827))),
              if (date.toString().isNotEmpty)
                Text(_formatDate(date.toString()), style: GoogleFonts.poppins(fontSize: 11, color: _mutedGrey)),
            ]),
            if (isAdmin) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: Text('Admin', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: _mintTitle)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Text(message, style: GoogleFonts.poppins(fontSize: 13.5, color: _bodyGrey, height: 1.6)),
        ]),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color c; Color bg; String label;
    switch (status) {
      case 'closed':      c = const Color(0xFF6B7280); bg = const Color(0xFFF3F4F6); label = 'Closed'; break;
      case 'resolved':    c = _mintTitle;              bg = const Color(0xFFDCFCE7); label = 'Resolved'; break;
      case 'in_progress': c = const Color(0xFF1D4ED8); bg = const Color(0xFFDBEAFE); label = 'In Progress'; break;
      default:            c = const Color(0xFFB45309); bg = const Color(0xFFFEF3C7); label = 'Open'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

// ── Small data models ─────────────────────────────────────────────────────────
class _Faq {
  final String q; final String a;
  const _Faq(this.q, this.a);
}

class _CardDef {
  final IconData icon; final String label; final String sub; final VoidCallback onTap;
  const _CardDef(this.icon, this.label, this.sub, this.onTap);
}

class _NavItem {
  final IconData icon; final String label;
  const _NavItem(this.icon, this.label);
}
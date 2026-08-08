import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../utils/responsive.dart';
import '../../core/api/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE — banner-matched colors (mint/light-green gradient from home banner)
// ─────────────────────────────────────────────────────────────────────────────
final Color _primary = AppTheme.primaryGreen; // 0xFF4CAF7D
const Color _primaryDark = Color(0xFF1F6B45); // banner tag/text dark green
final Color _accentEmerald = AppTheme.accentEmerald; // 0xFF7DCB9E
const _bgTop = Color(0xFFF7F5F2);
const _bgBottom = Color(0xFFF0EDE7);
const _ink = Color(0xFF111827);
const _bodyGrey = Color(0xFF6B7280);
const _mutedGrey = Color(0xFF9CA3AF);
const _glassLine = Color(0xFFFFFFFF);
const _danger = Color(0xFFDC2626);
const _amber = Color(0xFFB45309);
const _amberBg = Color(0xFFFEF3C7);

// Quick-action chip palette — banner-matched mint tones
const _chipDark = Color(
  0xFF1F6B45,
); // banner dark green (text/icon on light bg)
const _chipMid = Color(0xFF9AE0BC); // banner gradient end
const _chipLight = Color(
  0xFFDCF3E5,
); // banner gradient start (soft mint surface)

/// Gradient used for selected chips — matches home page banner gradient.
const LinearGradient _chipGradient = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const String _kBaseUrl = ApiConfig.baseUrl;
const String _supportEmail = 'admin@moneytries.com';

// Banner gradient — matches home page banner (mint → light sea-green)
const LinearGradient _brandGradient = LinearGradient(
  colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════
class _Faq {
  final String q;
  final String a;
  final String category;
  const _Faq(this.q, this.a, this.category);
}

class _TicketCategory {
  final String label;
  final IconData icon;
  final String
  prefix; // tagged into the subject — keeps backend schema unchanged
  const _TicketCategory(this.label, this.icon, this.prefix);
}

const _ticketCategories = [
  _TicketCategory('General', Icons.chat_bubble_outline_rounded, ''),
  _TicketCategory('Bug Report', Icons.bug_report_outlined, '[Bug] '),
  _TicketCategory(
    'Feature Request',
    Icons.lightbulb_outline_rounded,
    '[Feature] ',
  ),
  _TicketCategory(
    'Payment Issue',
    Icons.account_balance_wallet_outlined,
    '[Payment] ',
  ),
  _TicketCategory('Account & KYC', Icons.badge_outlined, '[Account] '),
];

const _faqCategories = [
  'All',
  'Account & KYC',
  'Deposits',
  'Withdrawals',
  'Investments',
  'Referral',
  'Security',
];

const _faqs = <_Faq>[
  _Faq(
    'How do I withdraw my earnings?',
    'Go to Home → Withdraw, enter the amount, and confirm with your security PIN. Withdrawals are processed within 24 hours to your linked bank account.',
    'Withdrawals',
  ),
  _Faq(
    'What is the minimum deposit amount?',
    'The minimum deposit is ₹500. There is no upper limit. Deposits reflect in your wallet instantly after payment confirmation.',
    'Deposits',
  ),
  _Faq(
    'Is my capital safe?',
    'Yes. Moneytries uses bank-grade encryption and follows strict fund segregation policies to ensure your capital is always protected.',
    'Security',
  ),
  _Faq(
    'How does the referral program work?',
    'Share your unique referral code. When your friend deposits and activates a plan, you earn 0.10% ROI on their investment as a bonus.',
    'Referral',
  ),
  _Faq(
    'What are the KYC requirements?',
    'You need a valid government-issued photo ID (Aadhaar or PAN) and a selfie. KYC is completed within 2 working hours.',
    'Account & KYC',
  ),
  _Faq(
    'How long do deposits take?',
    'Deposits via UPI and Net Banking are instant. NEFT/RTGS transfers may take up to 2 hours during banking hours.',
    'Deposits',
  ),
  _Faq(
    'How can I request a refund?',
    'Raise a ticket from this Support page and select "Payment Issue". Our team will review and process it within 3–5 business days.',
    'Withdrawals',
  ),
  _Faq(
    'What if my transaction fails?',
    'If money is debited but the transaction shows failed, it will be auto-reversed within 48 hours. You can also raise a support ticket for faster resolution.',
    'Deposits',
  ),
  _Faq(
    'How is my daily ROI calculated?',
    'ROI accrues daily based on your active plan\'s tiered rate and is credited automatically to your wallet every 24 hours.',
    'Investments',
  ),
  _Faq(
    'Can I change my investment plan mid-term?',
    'Active plans are fixed for their tenure. You can start a new plan alongside an existing one once your available balance permits it.',
    'Investments',
  ),
  _Faq(
    'How do I update my registered mobile number or email?',
    'Go to Profile → Personal Information to update your details. Sensitive changes may require re-verification via OTP.',
    'Account & KYC',
  ),
  _Faq(
    'How do I enable biometric login or app lock?',
    'Go to Profile → Security Settings to enable biometric login, set up a PIN lock, or turn on two-factor authentication.',
    'Security',
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// GLASS / NEUMORPHIC PRIMITIVES
// ═════════════════════════════════════════════════════════════════════════════

/// Frosted glass panel — blurred backdrop, soft dual shadow, translucent fill.
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final double blur;
  final double opacity;
  final Border? border;
  _Glass({
    required this.child,
    this.padding,
    this.radius,
    this.blur = 16,
    this.opacity = 0.6,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? BorderRadius.all(Radius.circular(22.r));
    final effectivePadding = padding ?? EdgeInsets.all(16.w);
    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: effectiveRadius,
            border:
                border ??
                Border.all(color: _glassLine.withOpacity(0.7), width: 1.2.r),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.75),
                offset: const Offset(-5, -5),
                blurRadius: 14,
              ),
              BoxShadow(
                color: _primary.withOpacity(0.10),
                offset: const Offset(7, 9),
                blurRadius: 20,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Soft neumorphic circular button (used for back, refresh, send, FAB).
class _SoftCircle extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool filled;
  final bool loading;
  const _SoftCircle({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.filled = false,
    this.loading = false,
  });

  @override
  State<_SoftCircle> createState() => _SoftCircleState();
}

class _SoftCircleState extends State<_SoftCircle> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: widget.filled ? _brandGradient : null,
            color: widget.filled ? null : Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
            border: widget.filled
                ? null
                : Border.all(color: Colors.white, width: 1.2.r),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(-4, -4),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: _primary.withOpacity(0.12),
                      offset: const Offset(5, 6),
                      blurRadius: 12,
                    ),
                  ],
          ),
          child: widget.loading
              ? Center(
                  child: SizedBox(
                    width: 17.w,
                    height: 17.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.filled ? _primaryDark : _primary,
                    ),
                  ),
                )
              : Icon(
                  widget.icon,
                  size: widget.size * 0.42,
                  color: widget.filled ? _primaryDark : _primaryDark,
                ),
        ),
      ),
    );
  }
}

/// Elongated soft neumorphic action button (primary CTA).
class _SoftAction extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool outline;
  const _SoftAction({
    required this.label,
    this.icon,
    required this.onTap,
    this.loading = false,
    this.outline = false,
  });

  @override
  State<_SoftAction> createState() => _SoftActionState();
}

class _SoftActionState extends State<_SoftAction> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 15.h),
          decoration: BoxDecoration(
            gradient: widget.outline ? null : _brandGradient,
            color: widget.outline ? Colors.white.withOpacity(0.65) : null,
            borderRadius: BorderRadius.circular(18.r),
            border: widget.outline
                ? Border.all(color: Colors.white, width: 1.2.r)
                : null,
            boxShadow: widget.outline
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(-4, -4),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: _primary.withOpacity(0.1),
                      offset: const Offset(5, 6),
                      blurRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _primary.withOpacity(0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.outline ? _primaryDark : _primaryDark,
                  ),
                )
              else ...[
                if (widget.icon != null)
                  Icon(
                    widget.icon,
                    size: 18.sp,
                    color: widget.outline ? _primaryDark : _primaryDark,
                  ),
                if (widget.icon != null) SizedBox(width: 8.w),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: widget.outline ? _primaryDark : _primaryDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Blurred, softly-glowing background blob.
class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN — chat-first: Tickets is the primary tab, FAQ is secondary
// ═════════════════════════════════════════════════════════════════════════════
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  int _tab = 0; // 0 = FAQ (primary), 1 = Tickets (secondary)

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgTop,
          body: Stack(
            children: [
              // ── Ambient gradient + blurred blobs backdrop ──────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_bgTop, _bgBottom],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: -60,
                right: -50,
                child: _Blob(size: 220.w, color: _primary.withOpacity(0.16)),
              ),
              Positioned(
                top: 220,
                left: -70,
                child: _Blob(
                  size: 180.w,
                  color: _accentEmerald.withOpacity(0.14),
                ),
              ),
              Positioned(
                bottom: 40,
                right: -60,
                child: _Blob(size: 200.w, color: _primary.withOpacity(0.10)),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    SizedBox(height: 6.h),
                    _buildTabSwitcher(),
                    SizedBox(height: 14.h),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _tab == 0
                            ? const _FaqPane(key: ValueKey('faq'))
                            : const _TicketsPane(key: ValueKey('tickets')),
                      ),
                    ),
                    _buildBottomNav(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0.h),
      child: Row(
        children: [
          _SoftCircle(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
            size: 42.w,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Help & Support',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: _Glass(
        padding: EdgeInsets.all(5.w),
        radius: BorderRadius.circular(18.r),
        blur: 14,
        opacity: 0.55,
        child: Row(
          children: [
            Expanded(child: _tabItem('FAQ', Icons.quiz_rounded, 0)),
            Expanded(child: _tabItem('Tickets', Icons.forum_rounded, 1)),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, IconData icon, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 11.h),
        decoration: BoxDecoration(
          gradient: selected ? _brandGradient : null,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp, color: selected ? _primaryDark : _bodyGrey),
            SizedBox(width: 7.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: selected ? _primaryDark : _bodyGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final navItems = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.trending_up_rounded, 'Plans'),
      _NavItem(Icons.history_rounded, 'History'),
      _NavItem(Icons.person_outline_rounded, 'Profile'),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 12.h),
      child: _Glass(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        radius: BorderRadius.circular(22.r),
        blur: 16,
        opacity: 0.65,
        child: Row(
          children: List.generate(navItems.length, (i) {
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  switch (i) {
                    case 0:
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (r) => false,
                      );
                      break;
                    case 1:
                      Navigator.pushNamed(context, AppRoutes.plan);
                      break;
                    case 2:
                      Navigator.pushNamed(context, AppRoutes.history);
                      break;
                    case 3:
                      Navigator.pushNamed(context, AppRoutes.profile);
                      break;
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(navItems[i].icon, size: 21.sp, color: _mutedGrey),
                    SizedBox(height: 3.h),
                    Text(
                      navItems[i].label,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: _mutedGrey,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TICKETS PANE — chat-first primary experience (inbox → compose → thread)
// ═════════════════════════════════════════════════════════════════════════════
enum _TicketView { inbox, compose, thread }

class _TicketsPane extends StatefulWidget {
  const _TicketsPane({super.key});
  @override
  State<_TicketsPane> createState() => _TicketsPaneState();
}

class _TicketsPaneState extends State<_TicketsPane> {
  _TicketView _view = _TicketView.inbox;

  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _replies = [];

  final _subjectCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  _TicketCategory _category = _ticketCategories[0];

  bool _loadingInbox = true;
  bool _loadingThread = false;
  bool _submitting = false;
  bool _replying = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _issueCtrl.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadTickets() async {
    setState(() => _loadingInbox = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/support/tickets'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final inner = body['data'] ?? body;
        setState(
          () => _tickets = List<Map<String, dynamic>>.from(
            inner['tickets'] ?? [],
          ),
        );
      } else {
        setState(() => _tickets = []);
      }
    } catch (_) {
      setState(() => _tickets = []);
    } finally {
      if (mounted) setState(() => _loadingInbox = false);
    }
  }

  Future<void> _submitTicket() async {
    final rawSubject = _subjectCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    if (rawSubject.isEmpty || issue.isEmpty) {
      _snack('Please fill in subject and issue.', error: true);
      return;
    }
    final subject = '${_category.prefix}$rawSubject';
    setState(() => _submitting = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final res = await http
          .post(
            Uri.parse('$_kBaseUrl/api/support/tickets'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'subject': subject, 'message': issue}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final inner = body['data'] ?? body;
        final newTicket = inner['ticket'] as Map<String, dynamic>?;
        _subjectCtrl.clear();
        _issueCtrl.clear();
        _category = _ticketCategories[0];
        await _loadTickets();
        if (newTicket != null) {
          await _openThread(newTicket);
        } else {
          setState(() => _view = _TicketView.inbox);
        }
        _snack('Ticket submitted! We\'ll respond soon.');
      } else {
        throw Exception('Failed to submit');
      }
    } catch (e) {
      _snack(
        'Error: ${e.toString().replaceAll("Exception: ", "")}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openThread(Map<String, dynamic> ticket) async {
    setState(() {
      _selectedTicket = ticket;
      _view = _TicketView.thread;
      _loadingThread = true;
      _replies = [];
    });
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final id = ticket['id'] ?? ticket['_id'];
      final res = await http
          .get(
            Uri.parse('$_kBaseUrl/api/support/tickets/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final inner = body['data'] ?? body;
        setState(() {
          _selectedTicket = Map<String, dynamic>.from(
            inner['ticket'] ?? ticket,
          );
          _replies = List<Map<String, dynamic>>.from(
            inner['replies'] ?? inner['messages'] ?? [],
          );
        });
      }
    } catch (_) {
      // keep current ticket data
    } finally {
      if (mounted) setState(() => _loadingThread = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendReply() async {
    final message = _replyCtrl.text.trim();
    if (message.isEmpty) return;
    final ticket = _selectedTicket;
    if (ticket == null) return;
    final id = ticket['id'] ?? ticket['_id'];

    setState(() => _replying = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not logged in');
      final res = await http
          .post(
            Uri.parse('$_kBaseUrl/api/support/tickets/$id/reply'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _replyCtrl.clear();
        await _openThread(ticket);
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to send reply');
      }
    } catch (e) {
      _snack(
        'Error: ${e.toString().replaceAll("Exception: ", "")}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: 'Times New Roman', fontSize: 13.sp),
        ),
        backgroundColor: error ? _danger : _primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _TicketView.inbox:
        return _buildInbox();
      case _TicketView.compose:
        return _buildCompose();
      case _TicketView.thread:
        return _buildThread();
    }
  }

  // ── Inbox ─────────────────────────────────────────────────────────────────
  Widget _buildInbox() {
    return Stack(
      children: [
        RefreshIndicator(
          color: _primary,
          onRefresh: _loadTickets,
          child: _loadingInbox
              ? ListView(
                  children: [
                    SizedBox(height: 120.h),
                    Center(child: CircularProgressIndicator(color: _primary)),
                  ],
                )
              : _tickets.isEmpty
              ? _buildEmptyInbox()
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 100.h),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (_, i) => _buildTicketPreview(_tickets[i]),
                ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Row(
            children: [
              Text(
                'New',
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _primaryDark,
                ),
              ),
              SizedBox(width: 8.w),
              _SoftCircle(
                icon: Icons.add_rounded,
                filled: true,
                size: 56.w,
                onTap: () => setState(() => _view = _TicketView.compose),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyInbox() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(28.w, 60.h, 28.w, 40.h),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _primary.withOpacity(0.16),
                      _accentEmerald.withOpacity(0.10),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(-6, -6),
                      blurRadius: 16,
                    ),
                    BoxShadow(
                      color: _primary.withOpacity(0.12),
                      offset: const Offset(7, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.forum_rounded,
                  size: 44.sp,
                  color: _primaryDark,
                ),
              ),
              SizedBox(height: 22.h),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Start a conversation with our support team.\nWe usually respond within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 13.sp,
                  color: _bodyGrey,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 26.h),
              _SoftAction(
                label: 'Start a Conversation',
                icon: Icons.add_comment_rounded,
                onTap: () => setState(() => _view = _TicketView.compose),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketPreview(Map<String, dynamic> ticket) {
    final status = (ticket['status'] ?? 'open').toString().toLowerCase();
    final subject = (ticket['subject'] ?? ticket['title'] ?? 'Support Ticket')
        .toString();
    final message = (ticket['message'] ?? ticket['description'] ?? '')
        .toString();
    final replyCount = ticket['reply_count'];
    final hasAdminReply =
        replyCount != null &&
        (replyCount is int
            ? replyCount > 0
            : int.tryParse(replyCount.toString()) != null &&
                  int.parse(replyCount.toString()) > 0);
    final updatedAt = (ticket['updated_at'] ?? ticket['created_at'] ?? '')
        .toString();

    final statusInfo = _statusInfo(status);

    return GestureDetector(
      onTap: () => _openThread(ticket),
      child: _Glass(
        radius: BorderRadius.circular(20.r),
        padding: EdgeInsets.all(14.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                gradient: hasAdminReply ? _brandGradient : null,
                color: hasAdminReply ? null : Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                border: hasAdminReply ? null : Border.all(color: Colors.white),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                size: 22.sp,
                color: hasAdminReply ? _primaryDark : _mutedGrey,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _stripPrefix(subject),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (updatedAt.isNotEmpty)
                        Text(
                          _formatShort(updatedAt),
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 10.5.sp,
                            color: _mutedGrey,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 12.5.sp,
                      color: _bodyGrey,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.$2,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          statusInfo.$3,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.$1,
                          ),
                        ),
                      ),
                      if (hasAdminReply) ...[
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.mark_chat_read_rounded,
                          size: 13.sp,
                          color: _primary,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Replied',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compose ───────────────────────────────────────────────────────────────
  Widget _buildCompose() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 30.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftCircle(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40.w,
                onTap: () => setState(() => _view = _TicketView.inbox),
              ),
              SizedBox(width: 12.w),
              Text(
                'New Conversation',
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          _Glass(
            radius: BorderRadius.circular(22.r),
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _bodyGrey,
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ticketCategories.map((cat) {
                    final selected = _category.label == cat.label;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 13.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: selected ? _chipGradient : null,
                          color: selected ? null : _chipLight.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: selected
                                ? _chipDark.withOpacity(0.6)
                                : _chipMid.withOpacity(0.5),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _chipDark.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 14.sp, color: _chipDark),
                            SizedBox(width: 6.w),
                            Text(
                              cat.label,
                              style: TextStyle(
                                fontFamily: 'Times New Roman',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: selected ? _chipDark : _bodyGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Subject',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _bodyGrey,
                  ),
                ),
                SizedBox(height: 8.h),
                _softField(_subjectCtrl, 'e.g. Withdrawal issue', maxLines: 1),
                SizedBox(height: 16.h),
                Text(
                  'Message',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _bodyGrey,
                  ),
                ),
                SizedBox(height: 8.h),
                _softField(
                  _issueCtrl,
                  'Describe the problem in detail so we can help you faster...',
                  maxLines: 6,
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _SoftAction(
            label: 'Send Message',
            icon: Icons.send_rounded,
            loading: _submitting,
            onTap: _submitTicket,
          ),
          SizedBox(height: 10.h),
          Center(
            child: Text(
              'Our team typically responds within 24 hours',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 11.5.sp,
                color: _mutedGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: _primary.withOpacity(0.08),
            offset: const Offset(3, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 13.5.sp,
          color: _ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 13.sp,
            color: _mutedGrey,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  // ── Thread ────────────────────────────────────────────────────────────────
  Widget _buildThread() {
    final ticket = _selectedTicket;
    if (ticket == null) return _buildInbox();
    final subject = _stripPrefix(
      (ticket['subject'] ?? ticket['title'] ?? 'Support Ticket').toString(),
    );
    final message = (ticket['message'] ?? ticket['description'] ?? '')
        .toString();
    final status = (ticket['status'] ?? 'open').toString().toLowerCase();
    final createdAt = (ticket['created_at'] ?? ticket['createdAt'] ?? '')
        .toString();
    final isClosed = status == 'closed';
    final statusInfo = _statusInfo(status);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 12.h),
          child: _Glass(
            radius: BorderRadius.circular(18.r),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                _SoftCircle(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 36.w,
                  onTap: () => setState(() => _view = _TicketView.inbox),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: BoxDecoration(
                              color: statusInfo.$1,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            statusInfo.$3,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 11.sp,
                              color: statusInfo.$1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SoftCircle(
                  icon: Icons.refresh_rounded,
                  size: 36.w,
                  onTap: () => _openThread(ticket),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 14.h),
            children: [
              _bubble(
                isAdmin: false,
                name: 'You',
                message: message,
                date: createdAt,
                isFirst: true,
              ),
              SizedBox(height: 12.h),
              if (_loadingThread)
                Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                )
              else if (_replies.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 30.sp,
                          color: _mutedGrey,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Awaiting a response from our team',
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 12.5.sp,
                            color: _bodyGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._replies.map((r) {
                  final isAdmin =
                      (r['sender_type'] ?? r['role'] ?? 'admin')
                          .toString()
                          .toLowerCase() ==
                      'admin';
                  final name =
                      (r['sender_name'] ?? (isAdmin ? 'Support Team' : 'You'))
                          .toString();
                  final msg = (r['message'] ?? r['content'] ?? '').toString();
                  final date = (r['created_at'] ?? r['createdAt'] ?? '')
                      .toString();
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _bubble(
                      isAdmin: isAdmin,
                      name: name,
                      message: msg,
                      date: date,
                      isFirst: false,
                    ),
                  );
                }),
            ],
          ),
        ),
        if (!isClosed)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 14.h),
            child: _Glass(
              radius: BorderRadius.circular(20.r),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontFamily: 'Times New Roman',
                        fontSize: 13.5.sp,
                        color: _ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 13.sp,
                          color: _mutedGrey,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  _SoftCircle(
                    icon: Icons.send_rounded,
                    filled: true,
                    size: 42.w,
                    loading: _replying,
                    onTap: _replying ? null : _sendReply,
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Center(
              child: Text(
                'This conversation is closed',
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 12.sp,
                  color: _mutedGrey,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bubble({
    required bool isAdmin,
    required String name,
    required String message,
    required String date,
    required bool isFirst,
  }) {
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: isAdmin
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin) ...[
                  Icon(
                    Icons.support_agent_rounded,
                    size: 13.sp,
                    color: _primaryDark,
                  ),
                  SizedBox(width: 4.w),
                ],
                Text(
                  isAdmin ? 'Support Team' : name,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _bodyGrey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: Radius.circular(isAdmin ? 4 : 18),
                bottomRight: Radius.circular(isAdmin ? 18 : 4),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 11.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: isAdmin
                        ? null
                        : LinearGradient(
                            colors: [
                              _primary.withOpacity(0.85),
                              _primaryDark.withOpacity(0.9),
                            ],
                          ),
                    color: isAdmin ? Colors.white.withOpacity(0.7) : null,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.r),
                      topRight: Radius.circular(18.r),
                      bottomLeft: Radius.circular(isAdmin ? 4 : 18),
                      bottomRight: Radius.circular(isAdmin ? 18 : 4),
                    ),
                    border: isAdmin ? Border.all(color: Colors.white) : null,
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 13.5.sp,
                      color: isAdmin ? _ink : Colors.white,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
            if (date.isNotEmpty) ...[
              SizedBox(height: 3.h),
              Text(
                _formatShort(date),
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 10.sp,
                  color: _mutedGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stripPrefix(String subject) {
    final match = RegExp(r'^\[[^\]]+\]\s*').firstMatch(subject);
    return match == null ? subject : subject.substring(match.end);
  }

  (Color, Color, String) _statusInfo(String status) {
    switch (status) {
      case 'closed':
        return (const Color(0xFF6B7280), const Color(0xFFF3F4F6), 'Closed');
      case 'resolved':
        return (_primaryDark, const Color(0xFFE8F5EE), 'Resolved');
      case 'in_progress':
        return (
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
          'In Progress',
        );
      default:
        return (_amber, _amberBg, 'Open');
    }
  }

  String _formatShort(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FAQ PANE — secondary: search + categorized expandable FAQs + more-help info
// ═════════════════════════════════════════════════════════════════════════════
class _FaqPane extends StatefulWidget {
  const _FaqPane({super.key});
  @override
  State<_FaqPane> createState() => _FaqPaneState();
}

class _FaqPaneState extends State<_FaqPane> {
  int? _expanded;
  String _query = '';
  String _category = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Faq> get _filtered {
    return _faqs.where((f) {
      final matchesCategory = _category == 'All' || f.category == _category;
      final matchesQuery =
          _query.isEmpty ||
          f.q.toLowerCase().contains(_query.toLowerCase()) ||
          f.a.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 30.h),
      children: [
        _Glass(
          radius: BorderRadius.circular(16.r),
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 13.5.sp,
              color: _ink,
            ),
            decoration: InputDecoration(
              hintText: 'Search FAQs — e.g. withdraw, KYC, ROI...',
              hintStyle: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 13.sp,
                color: _mutedGrey,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _primaryDark,
                size: 21.sp,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18.sp,
                        color: _mutedGrey,
                      ),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 14.h,
                horizontal: 6.w,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        SizedBox(
          height: 38.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _faqCategories.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final cat = _faqCategories[i];
              final selected = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected ? _chipGradient : null,
                    color: selected ? null : _chipLight.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? _chipDark.withOpacity(0.6)
                          : _chipMid.withOpacity(0.5),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: _chipDark.withOpacity(0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: selected ? _chipDark : _bodyGrey,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16.h),
        if (results.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 30.h),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 36.sp,
                    color: _mutedGrey,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'No FAQs match your search',
                    style: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 13.sp,
                      color: _bodyGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(results.length, (i) {
            final faq = results[i];
            final globalIndex = _faqs.indexOf(faq);
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _faqTile(faq, globalIndex, _expanded == globalIndex),
            );
          }),
        SizedBox(height: 24.h),
        _sectionLabel('Safety Tips', Icons.shield_rounded),
        SizedBox(height: 12.h),
        ..._safetyTips(),
        SizedBox(height: 24.h),
        _sectionLabel('Legal & App Info', Icons.info_rounded),
        SizedBox(height: 12.h),
        _legalCard(context),
      ],
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: _primaryDark),
        SizedBox(width: 7.w),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _faqTile(_Faq faq, int i, bool expanded) {
    return _Glass(
      radius: BorderRadius.circular(18.r),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: () => setState(() => _expanded = expanded ? null : i),
          child: Padding(
            padding: EdgeInsets.all(15.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 15.sp,
                        color: _primaryDark,
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Text(
                        faq.q,
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 13.3.sp,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.125 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.add_rounded,
                        size: 19.sp,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: expanded
                      ? Padding(
                          padding: EdgeInsets.only(top: 11.h, left: 39.w),
                          child: Text(
                            faq.a,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 12.8.sp,
                              color: _bodyGrey,
                              height: 1.6,
                            ),
                          ),
                        )
                      : SizedBox(width: double.infinity, height: 0.h),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _safetyTips() {
    final tips = [
      (
        Icons.password_rounded,
        'Never share your PIN or OTP',
        'Moneytries staff will never ask for your PIN, password, or OTP over call, chat, or email.',
      ),
      (
        Icons.link_off_rounded,
        'Avoid suspicious links',
        'Only use the official app or website. Don\'t click links from unknown SMS, WhatsApp, or email sources.',
      ),
      (
        Icons.verified_user_rounded,
        'Verify before you trust',
        'We never guarantee fixed abnormal returns. Be cautious of anyone promising unrealistic profits in our name.',
      ),
      (
        Icons.fingerprint_rounded,
        'Secure your device',
        'Enable biometric login and app lock from Security Settings to protect your account if your phone is lost.',
      ),
    ];
    return tips
        .map(
          (t) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _Glass(
              radius: BorderRadius.circular(16.r),
              padding: EdgeInsets.all(13.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(t.$1, size: 16.sp, color: _primaryDark),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.$2,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 12.8.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          t.$3,
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 11.8.sp,
                            color: _bodyGrey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _legalCard(BuildContext context) {
    return _Glass(
      radius: BorderRadius.circular(18.r),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _legalRow(
            context,
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => _showLegalSheet(
              context,
              'Privacy Policy',
              Icons.privacy_tip_outlined,
              _privacyPolicyText,
            ),
          ),
          Divider(
            height: 1.h,
            color: Colors.white.withOpacity(0.8),
            indent: 55,
          ),
          _legalRow(
            context,
            Icons.description_outlined,
            'Terms & Conditions',
            () => _showLegalSheet(
              context,
              'Terms & Conditions',
              Icons.description_outlined,
              _termsText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(icon, size: 16.sp, color: _primaryDark),
              ),
              SizedBox(width: 13.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12.sp,
                color: _mutedGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegalSheet(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E4DE),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(icon, size: 20.sp, color: _primaryDark),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1.h),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
                      child: Text(
                        content,
                        style: TextStyle(
                          fontFamily: 'Times New Roman',
                          fontSize: 13.sp,
                          color: _bodyGrey,
                          height: 1.75,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small data models ─────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// ── Static legal copy (kept local to this file, no backend or route changes) ─
const String _privacyPolicyText =
    '''
MoneyTries ("we", "our", "us") is committed to protecting your privacy. This policy explains how we collect, use, and safeguard your information.

Information We Collect
We collect information you provide during registration (name, email, phone number), KYC verification (government ID, selfie), and transaction activity (deposits, withdrawals, investment plans).

How We Use Your Information
Your data is used to verify your identity, process transactions, provide customer support, comply with regulatory requirements, and improve our services. We do not sell your personal information to third parties.

Data Security
We use bank-grade encryption, secure servers, and strict access controls to protect your data. Sensitive actions require PIN, biometric, or OTP verification.

Data Retention
We retain your information for as long as your account is active and as required by applicable financial regulations.

Your Rights
You may request access to, correction of, or deletion of your personal data by raising a support ticket. Certain data may be retained where required by law.

Third-Party Services
We may use trusted third-party providers for payment processing, SMS/email delivery, and analytics. These providers are bound by confidentiality obligations.

Changes to This Policy
We may update this policy periodically. Continued use of the app after changes constitutes acceptance of the revised policy.

Contact Us
For privacy-related questions, raise a support ticket from this page or write to $_supportEmail.
''';

const String _termsText =
    '''
Welcome to MoneyTries. By creating an account and using our services, you agree to the following terms.

Eligibility
You must be at least 18 years old and provide accurate KYC information to use our investment services.

Account Responsibility
You are responsible for maintaining the confidentiality of your login credentials, PIN, and OTP. Notify us immediately of any unauthorized access.

Investments & Returns
Investment plans carry a defined tenure and return-on-investment structure as displayed within the app at the time of subscription. Past performance is not a guarantee of future results.

Deposits & Withdrawals
Deposits are reflected upon payment confirmation. Withdrawals are processed to your linked, verified bank account within the timelines stated in the app.

Prohibited Activities
You may not use the platform for fraudulent activity, money laundering, or any unlawful purpose. Violations may result in account suspension.

Limitation of Liability
Moneytries is not liable for losses arising from market conditions, user negligence, or circumstances beyond our reasonable control.

Termination
We reserve the right to suspend or terminate accounts that violate these terms or applicable law.

Governing Law
These terms are governed by the laws of India. Any disputes shall be subject to the jurisdiction of the courts in Chennai, Tamil Nadu.

Contact Us
For questions about these terms, raise a support ticket or write to $_supportEmail.
''';
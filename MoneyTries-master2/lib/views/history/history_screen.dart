// lib/views/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/history/history_viewmodel.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/responsive.dart';
import '../../widgets/animations/animations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgColor        = Color(0xFFF7F5F2);
const _brandGreen     = Color(0xFF4CAF7D);
const _white          = Color(0xFFFFFFFF);
const _titleDark      = Color(0xFF111827);
const _subtitleGrey   = Color(0xFF6B7280);
const _labelGrey      = Color(0xFF9CA3AF);
const _surfaceWhite   = Color(0xFFFFFFFF);
const _dividerColor   = Color(0xFFE8E4DE);
const _successGreen   = Color(0xFF4CAF7D);
const _successBg      = Color(0xFFE8F5EE);
const _processingBg   = Color(0xFFEFF6FF);
const _processingText = Color(0xFF3B82F6);
const _failedBg       = Color(0xFFFEE2E2);
const _failedText     = Color(0xFFEF4444);
const _withdrawRed    = Color(0xFFEF4444);
const _sectionLabel   = Color(0xFF9CA3AF);

// ── Filters ───────────────────────────────────────────────────────────────────
enum _SortOrder { newest, oldest, amountHigh, amountLow }

extension on _SortOrder {
  String get label {
    switch (this) {
      case _SortOrder.newest:     return 'Newest first';
      case _SortOrder.oldest:     return 'Oldest first';
      case _SortOrder.amountHigh: return 'Amount: High to Low';
      case _SortOrder.amountLow:  return 'Amount: Low to High';
    }
  }
}

const List<(String, String)> _statusOptions = [
  ('all',      'All'),
  ('approved', 'Success'),
  ('pending',  'Processing'),
  ('rejected', 'Failed'),
];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedNavIndex = 2;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter state — persists across tabs until reset.
  String _statusFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  _SortOrder _sortOrder = _SortOrder.newest;

  int get _activeFilterCount {
    int c = 0;
    if (_statusFilter != 'all') c++;
    if (_fromDate != null || _toDate != null) c++;
    if (_sortOrder != _SortOrder.newest) c++;
    return c;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0 || _searchQuery.trim().isNotEmpty;

  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _fromDate = null;
      _toDate = null;
      _sortOrder = _SortOrder.newest;
    });
  }

  /// Applies search, status, date-range, and sort filters to a raw txn list.
  List<HistoryTxn> _applyFilters(List<HistoryTxn> raw, HistoryViewModel vm) {
    var list = vm.filtered(raw, _searchQuery);

    if (_statusFilter != 'all') {
      list = list.where((t) => t.status.toLowerCase() == _statusFilter).toList();
    }
    if (_fromDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      list = list.where((t) => t.date != null && !localDateOnly(t.date!).isBefore(start)).toList();
    }
    if (_toDate != null) {
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      list = list.where((t) => t.date != null && !toDeviceLocal(t.date!).isAfter(end)).toList();
    }

    list = List.of(list);
    switch (_sortOrder) {
      case _SortOrder.newest:
        list.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
        break;
      case _SortOrder.oldest:
        list.sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
        break;
      case _SortOrder.amountHigh:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _SortOrder.amountLow:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  final List<String> _tabs = ['Deposit', 'Withdraw', 'ROI', 'Referral', 'Wallet'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });

    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: _bgColor),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildSearchBar(),
                SizedBox(height: 10.h),
                _buildTabBar(),
                Divider(height: 1.h, thickness: 1, color: Color(0xFFE8E4DE)),
                Expanded(child: _buildBody()),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Body — switches on loading / error / content ──────────────────────────
  Widget _buildBody() {
    return Consumer<HistoryViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: _brandGreen),
          );
        }
        if (vm.error != null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 56.sp, color: _labelGrey.withOpacity(0.5)),
                  SizedBox(height: 16.h),
                  Text('Could not load history',
                      style: TextStyle(fontFamily: 'Times New Roman',
                          fontSize: 16.sp, fontWeight: FontWeight.w600, color: _subtitleGrey)),
                  SizedBox(height: 8.h),
                  Text(vm.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, color: _labelGrey)),
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    onPressed: vm.loadAll,
                    icon: Icon(Icons.refresh_rounded, size: 18.sp),
                    label: Text('Retry', style: TextStyle(fontFamily: 'Times New Roman',fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _brandGreen,
                        foregroundColor: _white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  ),
                ],
              ),
            ),
          );
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(vm.deposits,    _applyFilters(vm.deposits, vm),    vm, TxnType.deposit),
            _buildTabContent(vm.withdrawals, _applyFilters(vm.withdrawals, vm), vm, TxnType.withdrawal),
            _buildTabContent(vm.roiTxns,     _applyFilters(vm.roiTxns, vm),     vm, TxnType.roi),
            _buildTabContent(vm.referralTxns, _applyFilters(vm.referralTxns, vm), vm, TxnType.referral),
            _buildTabContent(vm.walletTxns,  _applyFilters(vm.walletTxns, vm),  vm, TxnType.wallet),
          ],
        );      },
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────
  Widget _buildTabContent(
      List<HistoryTxn> rawTxns, List<HistoryTxn> txns, HistoryViewModel vm, TxnType type) {
    final sectionError = vm.errorFor(type);
    if (sectionError != null && rawTxns.isEmpty) {
      return _buildSectionErrorState(sectionError, vm);
    }
    if (txns.isEmpty) {
      return _buildEmptyState(type, noResultsForFilter: rawTxns.isNotEmpty);
    }

    // Amount-based sorts don't map cleanly onto date sections — show a flat
    // list instead of grouping when sorted that way.
    final groupByDate =
        _sortOrder == _SortOrder.newest || _sortOrder == _SortOrder.oldest;

    final grouped = <String, List<HistoryTxn>>{};
    if (groupByDate) {
      for (final t in txns) {
        final label = _dateLabel(t.date);
        grouped.putIfAbsent(label, () => []).add(t);
      }
    }

    return RefreshIndicator(
      color: _brandGreen,
      onRefresh: vm.loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            if (_hasActiveFilters) _buildFilterSummaryBar(txns.length, rawTxns.length),
            SizedBox(height: 8.h),
            if (groupByDate)
              ...grouped.entries.map((e) => _buildSection(e.key, e.value))
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_sortOrder.label.toUpperCase(),
                        style: TextStyle(fontFamily: 'Times New Roman',
                            fontSize: 11.5.sp, fontWeight: FontWeight.w600,
                            color: _sectionLabel, letterSpacing: 1.2)),
                    SizedBox(height: 10.h),
                    ..._buildAnimatedTxnList(txns),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            SizedBox(height: 16.h),
            _buildSummaryCard(vm, type),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // ── Filter summary strip — shown above results when a filter/search is active ──
  Widget _buildFilterSummaryBar(int shown, int total) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $shown of $total',
              style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 12.sp, fontWeight: FontWeight.w500, color: _subtitleGrey),
            ),
          ),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              _resetFilters();
            },
            child: Text('Clear all',
                style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 12.sp, fontWeight: FontWeight.w700, color: _brandGreen)),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return 'EARLIER';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = localDateOnly(dt);
    if (d == today)                              return 'TODAY';
    if (d == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return DateFormat('d MMM yyyy').format(toDeviceLocal(dt)).toUpperCase();
  }

  // ── Section error state — the fetch itself failed (expired session, no
  // network, server error) rather than the user simply having zero records.
  // This must never be silently collapsed into the "No history yet" empty
  // state, or a real failure looks identical to having no transactions.
  Widget _buildSectionErrorState(String message, HistoryViewModel vm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56.sp, color: _labelGrey.withOpacity(0.5)),
            SizedBox(height: 16.h),
            Text('Could not load history',
                style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 16.sp, fontWeight: FontWeight.w600, color: _subtitleGrey)),
            SizedBox(height: 8.h),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Times New Roman',fontSize: 12.sp, color: _labelGrey)),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: vm.loadAll,
              icon: Icon(Icons.refresh_rounded, size: 18.sp),
              label: Text('Retry', style: TextStyle(fontFamily: 'Times New Roman',fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _brandGreen,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(TxnType type, {bool noResultsForFilter = false}) {
    if (noResultsForFilter) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_alt_off_rounded, size: 64.sp, color: _labelGrey.withOpacity(0.5)),
              SizedBox(height: 16.h),
              Text('No matching transactions',
                  style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 17.sp, fontWeight: FontWeight.w600, color: _subtitleGrey)),
              SizedBox(height: 6.h),
              Text('Try adjusting your search or filters',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Times New Roman',
                      fontSize: 13.sp, fontWeight: FontWeight.w400, color: _labelGrey)),
              SizedBox(height: 18.h),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _resetFilters();
                },
                icon: Icon(Icons.close_rounded, size: 16.sp, color: _brandGreen),
                label: Text('Clear filters',
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 13.sp, fontWeight: FontWeight.w600, color: _brandGreen)),
              ),
            ],
          ),
        ),
      );
    }

    final label = type == TxnType.deposit    ? 'No deposits yet'
                : type == TxnType.withdrawal ? 'No withdrawals yet'
                : type == TxnType.roi        ? 'No ROI earned yet'
                : type == TxnType.referral   ? 'No referral earnings yet'
                : 'No wallet transactions yet';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72.sp, color: _labelGrey.withOpacity(0.5)),
          SizedBox(height: 16.h),
          Text(label,
              style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 17.sp, fontWeight: FontWeight.w600, color: _subtitleGrey)),
          SizedBox(height: 6.h),
          Text('Your transaction history will appear here',
              style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 13.sp, fontWeight: FontWeight.w400, color: _labelGrey)),
        ],
      ),
    );
  }

  // ── Section ───────────────────────────────────────────────────────────────
  Widget _buildSection(String label, List<HistoryTxn> txns) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 11.5.sp, fontWeight: FontWeight.w600,
                  color: _sectionLabel, letterSpacing: 1.2)),
          SizedBox(height: 10.h),
          ..._buildAnimatedTxnList(txns),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  // ── Transaction card ──────────────────────────────────────────────────────
  // ── Animated list helper ─────────────────────────────────────────────────
  /// Wraps each transaction card in a staggered fade+slide entrance so the
  /// list cascades into place instead of appearing all at once.
  List<Widget> _buildAnimatedTxnList(List<HistoryTxn> txns) {
    return [
      for (int i = 0; i < txns.length; i++)
        StaggeredEntrance(index: i, child: _buildTxnCard(txns[i])),
    ];
  }

  Widget _buildTxnCard(HistoryTxn t) {
    final statusInfo = _statusInfo(t.status);
    final iconInfo   = _iconInfo(t.type, t.isCredit);
    // Always show the full date + time on the row itself, not just the time —
    // relying on the section header alone loses the date entirely whenever
    // the list isn't grouped by date (e.g. sorted by amount instead).
    final dateTimeStr = t.date != null
        ? DateFormat('d MMM yyyy, hh:mm a').format(toDeviceLocal(t.date!))
        : '';
    final amtColor   = t.isCredit ? _successGreen : _withdrawRed;

    return Container(
      key: ValueKey(t.id),
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 46.w, height: 46.h,
            decoration: BoxDecoration(color: iconInfo.$2, shape: BoxShape.circle),
            child: Icon(iconInfo.$1, size: 22.sp, color: iconInfo.$3),
          ),
          SizedBox(width: 14.w),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 14.5.sp, fontWeight: FontWeight.w600,
                        color: _titleDark, height: 1.3)),
                SizedBox(height: 3.h),
                Text(
                    '${t.subtitle}${dateTimeStr.isNotEmpty ? " • $dateTimeStr" : ""}',
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 12.sp, fontWeight: FontWeight.w400, color: _subtitleGrey)),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Amount + status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16.w, height: 16.h,
                    decoration: BoxDecoration(
                      color: amtColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      t.isCredit ? Icons.add : Icons.remove,
                      size: 10.sp, color: amtColor),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '₹${_fmt(t.amount)}',
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 14.5.sp, fontWeight: FontWeight.w700,
                        color: amtColor, letterSpacing: -0.2),
                  ),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                    color: statusInfo.$1,
                    borderRadius: BorderRadius.circular(6.r)),
                child: Text(statusInfo.$3,
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 10.sp, fontWeight: FontWeight.w700,
                        color: statusInfo.$2, letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Icon helper ───────────────────────────────────────────────────────────
  (IconData, Color, Color) _iconInfo(TxnType type, bool isCredit) {
    switch (type) {
      case TxnType.deposit:
        return (Icons.account_balance_outlined, const Color(0xFFE8F5EE), _brandGreen);
      case TxnType.withdrawal:
        return (Icons.wallet_outlined, const Color(0xFFFEE2E2), _withdrawRed);
      case TxnType.roi:
        return (Icons.trending_up_rounded, const Color(0xFFE8F5EE), _brandGreen);
      case TxnType.referral:
        return (Icons.people_alt_rounded, const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case TxnType.wallet:
        return (Icons.currency_rupee_rounded, const Color(0xFFE8F5EE), _brandGreen);
    }
  }

  // ── Status helper ─────────────────────────────────────────────────────────
  (Color, Color, String) _statusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return (_successBg, _successGreen, 'SUCCESS');
      case 'rejected':
        return (_failedBg, _failedText, 'FAILED');
      default:
        return (_processingBg, _processingText, 'PROCESSING');
    }
  }

  // ── Summary card ──────────────────────────────────────────────────────────
  Widget _buildSummaryCard(HistoryViewModel vm, TxnType type) {
    String label;
    double value;
    String sub;

    switch (type) {
      case TxnType.deposit:
        label = 'TOTAL DEPOSITED';
        value = vm.totalDeposited;
        sub   = 'Approved deposits only';
        break;
      case TxnType.withdrawal:
        label = 'TOTAL WITHDRAWN';
        value = vm.totalWithdrawn;
        sub   = 'Approved withdrawals only';
        break;
      case TxnType.roi:
        label = 'TOTAL ROI ACCRUED';
        value = vm.totalRoiAccrued;
        sub   = vm.roiWithdrawalCount > 0
            ? '₹${_fmt(vm.totalRoiWithdrawn)} withdrawn · ${vm.roiWithdrawalCount} transaction${vm.roiWithdrawalCount == 1 ? '' : 's'}'
            : 'Across all active plans';
        break;
      case TxnType.referral:
        label = 'TOTAL REFERRAL EARNINGS';
        value = vm.totalReferralEarnings;
        sub   = 'Bonuses + task rewards, all time';
        break;
      case TxnType.wallet:
        label = 'TOTAL WITHDRAWN';
        value = vm.totalWithdrawn;
        sub   = 'Approved withdrawals only';
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(22.w, 20.h, 22.w, 22.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFAEE5C6), width: 1.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6FC79A).withOpacity(0.25),
              blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8, top: -8,
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 100.sp, color: const Color(0xFF3E9E71).withOpacity(0.14)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 10.5.sp, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F6B45),
                        letterSpacing: 1.1)),
                SizedBox(height: 8.h),
                Text('₹${_fmt(value)}',
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 32.sp, fontWeight: FontWeight.w800,
                        color: const Color(0xFF2B2620), letterSpacing: -0.5, height: 1.1)),
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                      color: _white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: const Color(0xFFAEE5C6), width: 1.r)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14.sp, color: const Color(0xFF1F6B45)),
                      SizedBox(width: 5.w),
                      Text(sub,
                          style: TextStyle(fontFamily: 'Times New Roman',
                              fontSize: 12.sp, fontWeight: FontWeight.w500,
                              color: const Color(0xFF1F6B45))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(double v) {
    final nf = NumberFormat('#,##,##0.00', 'en_IN');
    return nf.format(v);
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20.sp, color: _titleDark),
          ),
          SizedBox(width: 14.w),
          Text('Transaction History',
              style: TextStyle(fontFamily: 'Times New Roman',
                  fontSize: 18.sp, fontWeight: FontWeight.w700,
                  color: _titleDark, letterSpacing: -0.3)),
          const Spacer(),
          Consumer<HistoryViewModel>(
            builder: (_, vm, __) => GestureDetector(
              onTap: vm.loadAll,
              child: Icon(Icons.refresh_rounded, size: 24.sp, color: _brandGreen),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46.h,
              decoration: BoxDecoration(
                color: _surfaceWhite,
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(color: _dividerColor, width: 1.r),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  SizedBox(width: 14.w),
                  Icon(Icons.search_rounded, size: 19.sp, color: _labelGrey),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontFamily: 'Times New Roman',fontSize: 14.sp, color: _titleDark),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: TextStyle(fontFamily: 'Times New Roman',
                            fontSize: 14.sp, color: _labelGrey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: Icon(Icons.close_rounded, size: 18.sp, color: _labelGrey),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 46.w, height: 46.h,
              decoration: BoxDecoration(
                color: _activeFilterCount > 0 ? _brandGreen : _surfaceWhite,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                    color: _activeFilterCount > 0 ? _brandGreen : _dividerColor, width: 1.r),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(Icons.tune_rounded, size: 20.sp,
                        color: _activeFilterCount > 0 ? _white : _brandGreen),
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      right: -2, top: -2,
                      child: Container(
                        width: 16.w, height: 16.h,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: _withdrawRed, shape: BoxShape.circle),
                        child: Text('$_activeFilterCount',
                            style: TextStyle(fontFamily: 'Times New Roman',
                                fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: _white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bottom sheet ──────────────────────────────────────────────────
  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _FilterSheet(
        initialStatus: _statusFilter,
        initialFrom: _fromDate,
        initialTo: _toDate,
        initialSort: _sortOrder,
        onApply: (status, from, to, sort) {
          setState(() {
            _statusFilter = status;
            _fromDate = from;
            _toDate = to;
            _sortOrder = sort;
          });
        },
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
      indicatorColor: _brandGreen,
      indicatorWeight: 2.5,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontFamily: 'Times New Roman',
          fontSize: 14.sp, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Times New Roman',
          fontSize: 14.sp, fontWeight: FontWeight.w400),
      labelColor: _brandGreen,
      unselectedLabelColor: _subtitleGrey,
      tabs: _tabs.map((t) => Tab(text: t, height: 40.h)).toList(),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  void _onNavTap(int i) {
    if (i == _selectedNavIndex) return;
    switch (i) {
      case 0: Navigator.pushNamed(context, AppRoutes.home); break;
      case 1: Navigator.pushNamed(context, AppRoutes.plan); break;
      case 3: Navigator.pushNamed(context, AppRoutes.profile); break;
      default: setState(() => _selectedNavIndex = i);
    }
  }

  Widget _buildBottomNav() {
    const navItems = [
      (icon: Icons.home_rounded,      label: 'HOME'),
      (icon: Icons.trending_up_rounded, label: 'PLAN'),
      (icon: Icons.history_rounded,   label: 'HISTORY'),
      (icon: Icons.person_rounded,    label: 'PROFILE'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
            top: BorderSide(color: Color(0xFFE8E4DE), width: 1.r)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62.h,
          child: Row(
            children: List.generate(navItems.length, (i) {
              final sel   = i == _selectedNavIndex;
              final color = sel
                  ? const Color(0xFF9AE0BC)
                  : const Color(0xFF9CA3AF);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onNavTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 3.h,
                        width: sel ? 32 : 0,
                        margin: EdgeInsets.only(bottom: 7.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9AE0BC),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      AnimatedNavIcon(
                        icon: navItems[i].icon,
                        selected: sel,
                        size: 22.sp,
                        selectedColor: const Color(0xFF9AE0BC),
                        unselectedColor: const Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        navItems[i].label,
                        style: TextStyle(fontFamily: 'Times New Roman',
                          fontSize: 10.sp,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Filter bottom sheet widget ────────────────────────────────────────────────
// Holds its own draft selections so Cancel/dismiss doesn't touch the parent's
// applied filters; only "Apply Filters" pushes the choice back up.
class _FilterSheet extends StatefulWidget {
  final String initialStatus;
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final _SortOrder initialSort;
  final void Function(String status, DateTime? from, DateTime? to, _SortOrder sort) onApply;

  const _FilterSheet({
    required this.initialStatus,
    required this.initialFrom,
    required this.initialTo,
    required this.initialSort,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  DateTime? _from;
  DateTime? _to;
  late _SortOrder _sort;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _from   = widget.initialFrom;
    _to     = widget.initialTo;
    _sort   = widget.initialSort;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _brandGreen),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      setState(() {
        _from = result.start;
        _to   = result.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cap the sheet at a fraction of the available screen height and let
    // the body scroll internally. Fixed-height Columns without a scroll
    // view overflow on shorter devices, smaller tablets in split view, or
    // when the keyboard/date picker temporarily shrinks the viewport.
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(
                    color: _dividerColor, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Text('Filters',
                    style: TextStyle(fontFamily: 'Times New Roman',
                        fontSize: 17.sp, fontWeight: FontWeight.w700, color: _titleDark)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _status = 'all';
                    _from = null;
                    _to = null;
                    _sort = _SortOrder.newest;
                  }),
                  child: Text('Reset',
                      style: TextStyle(fontFamily: 'Times New Roman',
                          fontSize: 13.sp, fontWeight: FontWeight.w600, color: _withdrawRed)),
                ),
              ],
            ),
            SizedBox(height: 22.h),

            // ── Status ──────────────────────────────────────────────────
            Text('STATUS',
                style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 11.5.sp, fontWeight: FontWeight.w600,
                    color: _sectionLabel, letterSpacing: 1.0)),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _statusOptions.map((opt) {
                final selected = _status == opt.$1;
                return GestureDetector(
                  onTap: () => setState(() => _status = opt.$1),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
                    decoration: BoxDecoration(
                      color: selected ? _brandGreen : _bgColor,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: selected ? _brandGreen : _dividerColor),
                    ),
                    child: Text(opt.$2,
                        style: TextStyle(fontFamily: 'Times New Roman',
                            fontSize: 13.sp, fontWeight: FontWeight.w600,
                            color: selected ? _white : _subtitleGrey)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 22.h),

            // ── Date range ──────────────────────────────────────────────
            Text('DATE RANGE',
                style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 11.5.sp, fontWeight: FontWeight.w600,
                    color: _sectionLabel, letterSpacing: 1.0)),
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16.sp, color: _brandGreen),
                    SizedBox(width: 10.w),
                    Text(
                      (_from != null && _to != null)
                          ? '${DateFormat('d MMM yyyy').format(_from!)} — ${DateFormat('d MMM yyyy').format(_to!)}'
                          : 'Select date range',
                      style: TextStyle(fontFamily: 'Times New Roman',
                          fontSize: 13.5.sp, fontWeight: FontWeight.w500,
                          color: (_from != null) ? _titleDark : _labelGrey),
                    ),
                    const Spacer(),
                    if (_from != null || _to != null)
                      GestureDetector(
                        onTap: () => setState(() { _from = null; _to = null; }),
                        child: Icon(Icons.close_rounded, size: 16.sp, color: _labelGrey),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 22.h),

            // ── Sort ────────────────────────────────────────────────────
            Text('SORT BY',
                style: TextStyle(fontFamily: 'Times New Roman',
                    fontSize: 11.5.sp, fontWeight: FontWeight.w600,
                    color: _sectionLabel, letterSpacing: 1.0)),
            SizedBox(height: 10.h),
            ..._SortOrder.values.map((s) {
              final selected = _sort == s;
              return GestureDetector(
                onTap: () => setState(() => _sort = s),
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: selected ? _successBg : _bgColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: selected ? _brandGreen : _dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 18.sp,
                        color: selected ? _brandGreen : _labelGrey,
                      ),
                      SizedBox(width: 10.w),
                      Text(s.label,
                          style: TextStyle(fontFamily: 'Times New Roman',
                              fontSize: 13.5.sp, fontWeight: FontWeight.w500,
                              color: _titleDark)),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 8.h),

            // ── Apply ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_status, _from, _to, _sort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandGreen,
                  foregroundColor: _white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text('Apply Filters',
                    style: TextStyle(fontFamily: 'Times New Roman',fontSize: 15.sp, fontWeight: FontWeight.w700)),
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/notification/notification_models.dart';
import '../../viewmodels/notification/notification_viewmodel.dart';
import '../../utils/date_time_utils.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = Color(0xFFECEFF5);
const _white = Color(0xFFFFFFFF);
const _titleDark = Color(0xFF111827);
const _subtitleGrey = Color(0xFF6B7280);
const _labelGrey = Color(0xFF9CA3AF);
const _brandGreen = Color(0xFF3D9E6A);
const _accentGreen = Color(0xFF3D9E6A);
const _divider = Color(0xFFE5E7EB);
const _unreadBg = Color(0xFFF0FDF4);
const _unreadDot = Color(0xFF3D9E6A);
const _errorRed = Color(0xFFDC2626);

// ── Entry point (wrapped with Provider) ───────────────────────────────────────
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationViewModel()..loadNotifications(),
      child: const _NotificationContent(),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────
class _NotificationContent extends StatefulWidget {
  const _NotificationContent();

  @override
  State<_NotificationContent> createState() => _NotificationContentState();
}

class _NotificationContentState extends State<_NotificationContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationViewModel>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, vm, _) {
        return Theme(
          data: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: _bg,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: _bg,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, vm),
                    Expanded(child: _buildBody(vm)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, NotificationViewModel vm) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _brandGreen, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
                if (vm.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accentGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${vm.unreadCount}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (vm.unreadCount > 0)
            GestureDetector(
              onTap: () async {
                await vm.markAllRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'All notifications marked as read',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      backgroundColor: _brandGreen,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accentGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _brandGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(NotificationViewModel vm) {
    if (vm.state == NotificationLoadState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accentGreen),
      );
    }

    if (vm.state == NotificationLoadState.error && vm.notifications.isEmpty) {
      return _buildErrorState(vm);
    }

    if (vm.notifications.isEmpty) {
      return _buildEmptyState();
    }

    // Group by date
    final grouped = _groupByDate(vm.notifications);

    return RefreshIndicator(
      color: _accentGreen,
      onRefresh: vm.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount:
            _countItems(grouped) +
            (vm.state == NotificationLoadState.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          return _buildItem(context, vm, grouped, index);
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    NotificationViewModel vm,
    List<_NotifGroup> groups,
    int index,
  ) {
    // Loading more indicator at the end
    final total = _countItems(groups);
    if (index == total) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: _accentGreen, strokeWidth: 2),
        ),
      );
    }

    // Flatten groups to get item/header
    int cursor = 0;
    for (final group in groups) {
      if (cursor == index) {
        // Date header
        return _buildDateHeader(group.label);
      }
      cursor++;
      for (final item in group.items) {
        if (cursor == index) {
          return _buildSwipeableTile(context, vm, item);
        }
        cursor++;
      }
    }
    return const SizedBox.shrink();
  }

  // ── Swipe-to-delete wrapper ───────────────────────────────────────────────
  Widget _buildSwipeableTile(
    BuildContext context,
    NotificationViewModel vm,
    NotificationItem item,
  ) {
    return Dismissible(
      // Keyed by notification id so Flutter tracks each tile independently —
      // dismissing one never touches any other tile's state or animation.
      key: ValueKey('notif_${item.id}'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(alignment: Alignment.centerLeft),
      secondaryBackground: _buildSwipeBackground(alignment: Alignment.centerRight),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _handleDelete(context, vm, item),
      child: _NotifTile(item: item, onTap: () => vm.markAsRead(item.id)),
    );
  }

  // Red delete backdrop with a trash icon, revealed as the tile is dragged.
  Widget _buildSwipeBackground({required Alignment alignment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: _errorRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: _white,
        size: 26,
      ),
    );
  }

  // Material-style confirmation dialog shown once the swipe threshold is
  // crossed — the tile only actually dismisses if the user taps "Delete".
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete notification?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        content: Text(
          'This notification will be permanently removed.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: _subtitleGrey,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _subtitleGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _errorRed,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // Removes the notification (optimistically) and shows an "Undo" snackbar.
  // If the undo window lapses, the viewmodel finalizes the delete against
  // the backend; if it fails there, the notification is restored and an
  // error snackbar is shown. Scoped entirely to this one notification's id.
  void _handleDelete(
    BuildContext context,
    NotificationViewModel vm,
    NotificationItem item,
  ) {
    final removed = vm.beginDelete(
      item.id,
      onError: (message) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete notification: $message',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: _errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );

    if (!removed || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Notification deleted',
            style: GoogleFonts.inter(fontSize: 13, color: _white),
          ),
          backgroundColor: _titleDark,
          duration: NotificationViewModel.undoWindow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: _accentGreen,
            onPressed: () => vm.undoDelete(item.id),
          ),
        ),
      );
  }

  int _countItems(List<_NotifGroup> groups) {
    int count = 0;
    for (final g in groups) {
      count += 1 + g.items.length; // header + items
    }
    return count;
  }

  // ── Date header ───────────────────────────────────────────────────────────
  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _labelGrey,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 38,
                color: _accentGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notifications yet',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You're all caught up!\nWe'll notify you about deposits,\nwithdrawals, and more.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildErrorState(NotificationViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _errorRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: _errorRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _titleDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              vm.errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _subtitleGrey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: vm.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: _white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Group by date ─────────────────────────────────────────────────────────
  List<_NotifGroup> _groupByDate(List<NotificationItem> items) {
    // Group by the device's actual local calendar day — not a hard-coded
    // IST offset — so "Today" / "Yesterday" are correct for every user,
    // regardless of which timezone their device is set to.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationItem>> map = {};
    for (final item in items) {
      final date = item.createdAt != null
          ? localDateOnly(item.createdAt!)
          : today;
      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else {
        label = '${_monthName(date.month)} ${date.day}, ${date.year}';
      }
      map.putIfAbsent(label, () => []).add(item);
    }

    // preserve insertion order
    return map.entries.map((e) => _NotifGroup(e.key, e.value)).toList();
  }

  String _monthName(int m) {
    const names = [
      '',
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
    return names[m];
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotifTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeInfo = _typeInfo(item.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? _white : _unreadBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFE5E7EB)
                  : _accentGreen.withOpacity(0.3),
              width: item.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeInfo.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeInfo.icon, color: typeInfo.iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: _titleDark,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, left: 8),
                            decoration: const BoxDecoration(
                              color: _unreadDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _subtitleGrey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: _labelGrey,
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

  _TypeInfo _typeInfo(NotificationType type) {
    switch (type) {
      case NotificationType.deposit:
        return _TypeInfo(
          icon: Icons.add_circle_outline_rounded,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
        );
      case NotificationType.withdrawal:
        return _TypeInfo(
          icon: Icons.remove_circle_outline_rounded,
          iconBg: const Color(0xFFFEE2E2),
          iconColor: const Color(0xFFDC2626),
        );
      case NotificationType.kyc:
        return _TypeInfo(
          icon: Icons.verified_user_outlined,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
        );
      case NotificationType.referral:
        return _TypeInfo(
          icon: Icons.people_outline_rounded,
          iconBg: const Color(0xFFF5F3FF),
          iconColor: const Color(0xFF7C3AED),
        );
      case NotificationType.roi:
        return _TypeInfo(
          icon: Icons.trending_up_rounded,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
        );
      case NotificationType.plan:
        return _TypeInfo(
          icon: Icons.pie_chart_outline_rounded,
          iconBg: const Color(0xFFE0E7FF),
          iconColor: const Color(0xFF4F46E5),
        );
      case NotificationType.system:
      default:
        return _TypeInfo(
          icon: Icons.notifications_outlined,
          iconBg: const Color(0xFFE9F3EE),
          iconColor: _accentGreen,
        );
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    // Convert to the device's real local timezone — the server always
    // sends UTC, so this is the single place that turns it into the time
    // the user actually sees on their clock.
    final local = toDeviceLocal(dt);
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_tileMonthName(local.month)} ${local.day}, ${local.year} • $hour12:$minute $period';
  }

  String _tileMonthName(int m) {
    const names = [
      '',
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
    return names[m];
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _NotifGroup {
  final String label;
  final List<NotificationItem> items;
  const _NotifGroup(this.label, this.items);
}

class _TypeInfo {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  const _TypeInfo({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
}
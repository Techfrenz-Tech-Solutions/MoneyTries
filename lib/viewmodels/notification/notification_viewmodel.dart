import 'package:flutter/foundation.dart';
import '../../data/notification/notification_repository.dart';
import '../../models/notification/notification_models.dart';

enum NotificationLoadState { idle, loading, loadingMore, success, error }

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _repo;

  NotificationViewModel({NotificationRepository? repository})
      : _repo = repository ?? NotificationRepository();

  // ── State ──────────────────────────────────────────────────────────────────
  NotificationLoadState state = NotificationLoadState.idle;
  String? errorMessage;

  // ── Data ───────────────────────────────────────────────────────────────────
  final List<NotificationItem> notifications = [];
  int _pageNo = 1;
  static const int _pageSize = 20;
  bool hasMore = true;
  int unreadCount = 0;

  // ── Load first page ────────────────────────────────────────────────────────
  Future<void> loadNotifications() async {
    state = NotificationLoadState.loading;
    errorMessage = null;
    notifications.clear();
    _pageNo = 1;
    hasMore = true;
    notifyListeners();

    try {
      final resp = await _repo.fetchNotifications(pageNo: 1, pageSize: _pageSize);
      notifications.addAll(resp.data);
      unreadCount = resp.unreadCount;
      hasMore = _pageNo < resp.totalPages;
      state = NotificationLoadState.success;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      state = NotificationLoadState.error;
    }

    notifyListeners();
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> loadMore() async {
    if (!hasMore || state == NotificationLoadState.loadingMore) return;

    state = NotificationLoadState.loadingMore;
    notifyListeners();

    try {
      _pageNo++;
      final resp = await _repo.fetchNotifications(pageNo: _pageNo, pageSize: _pageSize);
      notifications.addAll(resp.data);
      unreadCount = resp.unreadCount;
      hasMore = _pageNo < resp.totalPages;
      state = NotificationLoadState.success;
    } catch (e) {
      _pageNo--; // revert on failure
      state = NotificationLoadState.success; // keep existing list visible
    }

    notifyListeners();
  }

  // ── Mark single read ───────────────────────────────────────────────────────
  Future<void> markAsRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || notifications[idx].isRead) return;

    // Optimistic update
    notifications[idx] = notifications[idx].copyWith(isRead: true);
    if (unreadCount > 0) unreadCount--;
    notifyListeners();

    try {
      await _repo.markAsRead(id);
    } catch (_) {
      // Revert on failure
      notifications[idx] = notifications[idx].copyWith(isRead: false);
      if (notifications[idx].isRead == false) unreadCount++;
      notifyListeners();
    }
  }

  // ── Mark all read ──────────────────────────────────────────────────────────
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;

    // Optimistic update
    for (int i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
    unreadCount = 0;
    notifyListeners();

    try {
      await _repo.markAllRead();
    } catch (_) {
      // On failure, reload to get actual state
      await loadNotifications();
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  Future<void> refresh() => loadNotifications();
}
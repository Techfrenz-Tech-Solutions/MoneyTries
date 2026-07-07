import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/notification/notification_repository.dart';
import '../../models/notification/notification_models.dart';

enum NotificationLoadState { idle, loading, loadingMore, success, error }

/// Tracks a notification that's been removed from the visible list but
/// hasn't been permanently deleted from the database yet — gives the user
/// a grace window to tap "Undo" before it's gone for good.
class _PendingDelete {
  final NotificationItem item;
  final int index;
  final Timer timer;
  _PendingDelete({required this.item, required this.index, required this.timer});
}

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _repo;

  NotificationViewModel({NotificationRepository? repository})
      : _repo = repository ?? NotificationRepository();

  /// How long a deleted notification stays undoable before the delete is
  /// finalized against the backend. Kept in sync with the "Undo" snackbar
  /// duration shown in the UI.
  static const Duration undoWindow = Duration(seconds: 4);

  // Keyed by notification id — supports independent, concurrent pending
  // deletes so removing one notification never affects any other.
  final Map<String, _PendingDelete> _pendingDeletes = {};

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

  // ── Delete (swipe-to-delete) ─────────────────────────────────────────────
  /// Removes [id] from the visible list immediately (so the swipe feels
  /// instant) and schedules the permanent backend delete after
  /// [undoWindow] unless [undoDelete] is called first. Returns false if the
  /// notification wasn't found (e.g. already removed).
  ///
  /// [onError] is invoked if the eventual backend delete fails, after the
  /// notification has already been restored to the list.
  bool beginDelete(String id, {void Function(String message)? onError}) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return false;

    // Cancel any stale pending-delete for this id before starting a new one.
    _pendingDeletes.remove(id)?.timer.cancel();

    final item = notifications[idx];
    notifications.removeAt(idx);
    if (!item.isRead && unreadCount > 0) unreadCount--;
    notifyListeners();

    final timer = Timer(undoWindow, () => _finalizeDelete(id, onError: onError));
    _pendingDeletes[id] = _PendingDelete(item: item, index: idx, timer: timer);
    return true;
  }

  /// Restores a notification removed by [beginDelete], provided the undo
  /// window hasn't expired yet. No-op if it's already been finalized.
  void undoDelete(String id) {
    final pending = _pendingDeletes.remove(id);
    if (pending == null) return;
    pending.timer.cancel();

    final insertAt = pending.index.clamp(0, notifications.length);
    notifications.insert(insertAt, pending.item);
    if (!pending.item.isRead) unreadCount++;
    notifyListeners();
  }

  Future<void> _finalizeDelete(String id, {void Function(String message)? onError}) async {
    final pending = _pendingDeletes.remove(id);
    if (pending == null) return;

    try {
      await _repo.deleteNotification(id);
      // Success — the notification is already gone from the visible list,
      // nothing further to do.
    } catch (e) {
      // Backend delete failed — restore it so the user doesn't silently
      // lose a notification that's still sitting in the database. This
      // only ever touches this single notification's entry.
      final insertAt = pending.index.clamp(0, notifications.length);
      notifications.insert(insertAt, pending.item);
      if (!pending.item.isRead) unreadCount++;
      notifyListeners();
      onError?.call(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    for (final pending in _pendingDeletes.values) {
      pending.timer.cancel();
    }
    _pendingDeletes.clear();
    super.dispose();
  }
}
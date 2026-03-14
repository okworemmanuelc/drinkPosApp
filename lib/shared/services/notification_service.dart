import 'package:flutter/foundation.dart';
import '../../core/database/repositories/log_repository.dart';
import '../models/notification.dart';

class NotificationService extends ValueNotifier<List<NotificationModel>> {
  NotificationService() : super([]);

  Future<void> init() async {
    value = await logRepository.getAllNotifications();
  }

  void createNotification(String type, String message, {String? linkedRecordId}) {
    final n = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
      linkedRecordId: linkedRecordId,
    );
    value = [n, ...value];
    logRepository.insertNotification(n);
  }

  void markAsRead(String id) {
    final index = value.indexWhere((n) => n.id == id);
    if (index != -1) {
      final newList = List<NotificationModel>.from(value);
      newList[index] = newList[index].copyWith(isRead: true);
      value = newList;
      logRepository.updateNotification(newList[index]);
    }
  }

  void markAllAsRead() {
    value = value.map((n) => n.copyWith(isRead: true)).toList();
    for (final n in value) {
      logRepository.updateNotification(n);
    }
  }

  void deleteNotification(String id) {
    value = value.where((n) => n.id != id).toList();
    logRepository.deleteNotification(id);
  }

  void clearAll() {
    value = [];
    logRepository.clearAllNotifications();
  }

  int get unreadCount => value.where((n) => !n.isRead).length;
}

final notificationService = NotificationService();

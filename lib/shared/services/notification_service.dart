import 'package:flutter/foundation.dart';
import '../models/notification.dart';

class NotificationService extends ValueNotifier<List<NotificationModel>> {
  NotificationService() : super([]);

  void createNotification(String type, String message, {String? linkedRecordId}) {
    final newNotification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
      linkedRecordId: linkedRecordId,
    );
    value = [newNotification, ...value];
  }

  void markAsRead(String id) {
    final index = value.indexWhere((n) => n.id == id);
    if (index != -1) {
      final newList = List<NotificationModel>.from(value);
      newList[index] = newList[index].copyWith(isRead: true);
      value = newList;
    }
  }

  void markAllAsRead() {
    value = value.map((n) => n.copyWith(isRead: true)).toList();
  }

  void deleteNotification(String id) {
    value = value.where((n) => n.id != id).toList();
  }

  void clearAll() {
    value = [];
  }

  int get unreadCount => value.where((n) => !n.isRead).length;
}

final notificationService = NotificationService();

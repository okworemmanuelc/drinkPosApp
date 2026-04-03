import 'package:flutter/foundation.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/models/notification.dart';

class NotificationService extends ValueNotifier<List<NotificationModel>> {
  NotificationService() : super([]) {
    _init();
  }

  void _init() {
    database.notificationsDao.watchAll().listen((notifsData) {
      value = notifsData.map((data) => NotificationModel.fromDb(data)).toList();
    });
  }

  Future<void> createNotification(
    String type,
    String message, {
    String? linkedRecordId,
  }) async {
    await database.notificationsDao.create(
      type,
      message,
      linkedRecordId: linkedRecordId,
    );
  }

  Future<void> markAsRead(String id) async {
    final intId = int.tryParse(id);
    if (intId != null) {
      await database.notificationsDao.markRead(intId);
    }
  }

  Future<void> markAllAsRead() async {
    await database.notificationsDao.markAllRead();
  }

  Future<void> deleteNotification(String id) async {
    final intId = int.tryParse(id);
    if (intId != null) {
      await database.notificationsDao.deleteSingle(intId);
    }
  }

  Future<void> clearAll() async {
    await database.notificationsDao.clearAll();
  }

  int get unreadCount => value.where((n) => !n.isRead).length;
}

final notificationService = NotificationService();

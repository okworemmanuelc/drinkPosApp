import 'package:flutter/widgets.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/models/activity_log.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';

class ActivityLogService extends ValueNotifier<List<ActivityLog>> {
  ActivityLogService() : super([]) {
    _init();
  }

  void _init() {
    database.activityLogDao.watchRecent().listen((logsData) {
      value = logsData.map((data) => ActivityLog.fromDb(data)).toList();
    });
  }

  Future<void> logAction(
    String action,
    String description, {
    String? relatedEntityId,
    String? relatedEntityType,
    String? warehouseId,
  }) async {
    await database.activityLogDao.log(
      staffId: authService.currentUser?.id,
      action: action,
      description: description,
      entityId: relatedEntityId,
      entityType: relatedEntityType,
      warehouseId: warehouseId,
    );
  }

  Future<List<ActivityLog>> getForEntity(String entityId) async {
    final data = await database.activityLogDao.getForEntity(entityId);
    return data.map((d) => ActivityLog.fromDb(d)).toList();
  }
}

// Global instance available app-wide
final ActivityLogService activityLogService = ActivityLogService();

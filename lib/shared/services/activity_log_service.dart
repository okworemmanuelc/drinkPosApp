import 'package:flutter/widgets.dart';
import '../../core/database/app_database.dart';
import '../models/activity_log.dart';
import './auth_service.dart';

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
    final staffId = authService.currentUser?.id;
    
    await database.activityLogDao.log(
      staffId: staffId,
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

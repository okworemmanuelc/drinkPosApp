import 'package:flutter/widgets.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/models/activity_log.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';

class ActivityLogService extends ValueNotifier<List<ActivityLog>> {
  final AppDatabase _db;
  final AuthService _auth;

  ActivityLogService(this._db, this._auth) : super([]) {
    _init();
  }

  void _init() {
    _db.activityLogDao.watchRecent().listen((logsData) {
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
    await _db.activityLogDao.log(
      staffId: _auth.currentUser?.id,
      action: action,
      description: description,
      entityId: relatedEntityId,
      entityType: relatedEntityType,
      warehouseId: warehouseId,
    );
  }

  Future<List<ActivityLog>> getForEntity(String entityId) async {
    final data = await _db.activityLogDao.getForEntity(entityId);
    return data.map((d) => ActivityLog.fromDb(d)).toList();
  }
}


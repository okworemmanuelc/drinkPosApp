import 'package:ribaplus_pos/core/database/app_database.dart';

class ActivityLog {
  final String id;
  final String action;
  final String description;
  final DateTime timestamp;
  final String? relatedEntityId;
  final String? relatedEntityType;
  final String? warehouseId;
  final int? userId;

  ActivityLog({
    required this.id,
    required this.action,
    required this.description,
    required this.timestamp,
    this.relatedEntityId,
    this.relatedEntityType,
    this.warehouseId,
    this.userId,
  });

  factory ActivityLog.fromDb(ActivityLogData data) {
    return ActivityLog(
      id: data.id.toString(),
      action: data.action,
      description: data.description,
      timestamp: data.timestamp,
      relatedEntityId: data.relatedEntityId,
      relatedEntityType: data.relatedEntityType,
      warehouseId: data.warehouseId,
      userId: data.userId,
    );
  }
}

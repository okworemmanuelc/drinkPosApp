import 'package:flutter/widgets.dart';
import '../models/activity_log.dart';

class ActivityLogService extends ValueNotifier<List<ActivityLog>> {
  ActivityLogService() : super([]);

  void logAction(
    String action,
    String description, {
    String? relatedEntityId,
    String? relatedEntityType,
  }) {
    final newLog = ActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
      action: action,
      description: description,
      timestamp: DateTime.now(),
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
    );

    // Keep logs immutable by creating a new list
    value = [newLog, ...value];
  }
}

// Global instance available app-wide
final ActivityLogService activityLogService = ActivityLogService();

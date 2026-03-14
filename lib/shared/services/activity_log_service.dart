import 'package:flutter/widgets.dart';
import '../../core/database/repositories/log_repository.dart';
import '../models/activity_log.dart';

class ActivityLogService extends ValueNotifier<List<ActivityLog>> {
  ActivityLogService() : super([]);

  Future<void> init() async {
    value = await logRepository.getAllActivityLogs();
  }

  void logAction(
    String action,
    String description, {
    String? relatedEntityId,
    String? relatedEntityType,
  }) {
    final log = ActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      description: description,
      timestamp: DateTime.now(),
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
    );
    value = [log, ...value];
    logRepository.insertActivityLog(log);
  }
}

final ActivityLogService activityLogService = ActivityLogService();

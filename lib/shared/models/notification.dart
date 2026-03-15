import 'package:ribaplus_pos/core/database/app_database.dart';

class NotificationModel {
  final String id;
  final String type; // 'new_order', 'low_stock', 'large_expense', 'failed_transaction', etc.
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? linkedRecordId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.linkedRecordId,
  });

  factory NotificationModel.fromDb(NotificationData data) {
    return NotificationModel(
      id: data.id.toString(),
      type: data.type,
      message: data.message,
      timestamp: data.timestamp,
      isRead: data.isRead,
      linkedRecordId: data.linkedRecordId,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? type,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? linkedRecordId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      linkedRecordId: linkedRecordId ?? this.linkedRecordId,
    );
  }
}

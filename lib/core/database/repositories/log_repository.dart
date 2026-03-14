import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../../../shared/models/activity_log.dart';
import '../../../shared/models/notification.dart';
import '../../../features/inventory/data/models/inventory_log.dart';

const _uuid = Uuid();

class LogRepository {
  // ── ActivityLog ──────────────────────────────────────────────────────────────

  Future<List<ActivityLog>> getAllActivityLogs() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'activity_logs',
      where: 'deleted_at IS NULL',
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => ActivityLog(
      id: r['id'] as String,
      action: r['action'] as String,
      description: r['description'] as String,
      timestamp: DateTime.parse(r['timestamp'] as String),
      relatedEntityId: r['related_entity_id'] as String?,
      relatedEntityType: r['related_entity_type'] as String?,
    )).toList();
  }

  Future<void> insertActivityLog(ActivityLog log) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('activity_logs', {
      'id': log.id,
      'action': log.action,
      'description': log.description,
      'timestamp': log.timestamp.toIso8601String(),
      'related_entity_id': log.relatedEntityId,
      'related_entity_type': log.relatedEntityType,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  // ── InventoryLog ─────────────────────────────────────────────────────────────

  Future<List<InventoryLog>> getAllInventoryLogs() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'inventory_logs',
      where: 'deleted_at IS NULL',
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => InventoryLog(
      timestamp: DateTime.parse(r['timestamp'] as String),
      user: r['user'] as String,
      itemId: r['item_id'] as String,
      itemName: r['item_name'] as String,
      action: r['action'] as String,
      previousValue: (r['previous_value'] as num).toDouble(),
      newValue: (r['new_value'] as num).toDouble(),
      note: r['note'] as String?,
    )).toList();
  }

  Future<void> insertInventoryLog(InventoryLog log) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('inventory_logs', {
      'id': _uuid.v4(),
      'timestamp': log.timestamp.toIso8601String(),
      'user': log.user,
      'item_id': log.itemId,
      'item_name': log.itemName,
      'action': log.action,
      'previous_value': log.previousValue,
      'new_value': log.newValue,
      'note': log.note,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  // ── Notifications ─────────────────────────────────────────────────────────────

  Future<List<NotificationModel>> getAllNotifications() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'notifications',
      where: 'deleted_at IS NULL',
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => NotificationModel(
      id: r['id'] as String,
      type: r['type'] as String,
      message: r['message'] as String,
      timestamp: DateTime.parse(r['timestamp'] as String),
      isRead: (r['is_read'] as int) == 1,
      linkedRecordId: r['linked_record_id'] as String?,
    )).toList();
  }

  Future<void> insertNotification(NotificationModel n) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('notifications', {
      'id': n.id,
      'type': n.type,
      'message': n.message,
      'timestamp': n.timestamp.toIso8601String(),
      'is_read': n.isRead ? 1 : 0,
      'linked_record_id': n.linkedRecordId,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<void> updateNotification(NotificationModel n) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notifications',
      {'is_read': n.isRead ? 1 : 0, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [n.id],
    );
  }

  Future<void> deleteNotification(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notifications',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllNotifications() async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notifications',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'deleted_at IS NULL',
    );
  }
}

final logRepository = LogRepository();

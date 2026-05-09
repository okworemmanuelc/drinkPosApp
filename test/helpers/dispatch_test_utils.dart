import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

/// Builds a fresh in-memory Drift DB, registers the business id resolver,
/// inserts a single Businesses row, and returns the DB. Mirrors the pattern
/// already in use in test/customers/add_customer_atomicity_test.dart.
Future<({AppDatabase db, String businessId})> bootstrapTestDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final businessId = UuidV7.generate();
  db.businessIdResolver = () => businessId;
  await db.into(db.businesses).insert(
        BusinessesCompanion.insert(id: Value(businessId), name: 'Test Biz'),
      );
  return (db: db, businessId: businessId);
}

/// Sets a feature flag in the local system_config table. Tier-1 tests use
/// this to drive the v2 dispatch path without hitting the cloud.
Future<void> setFlag(AppDatabase db, String key, {required bool on}) async {
  await db.systemConfigDao.set(key, on ? 'true' : 'false');
}

/// Reads every pending sync_queue row, ordered by createdAt ascending.
Future<List<SyncQueueData>> getPendingQueue(AppDatabase db) async {
  return (db.select(db.syncQueue)
        ..where((t) => t.status.equals('pending'))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();
}

/// Decodes a sync_queue row's payload into a Map for assertion shape checks.
Map<String, dynamic> decodePayload(SyncQueueData row) {
  return jsonDecode(row.payload) as Map<String, dynamic>;
}

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';

import '../helpers/dispatch_test_utils.dart';

/// §6.8 — failure classes for SyncDao.markFailed.
///
/// permanent → orphan auto-move (row leaves sync_queue, lands in
/// sync_queue_orphans with `original_id` preserved).
/// fkDeferred → stays pending with a long backoff and capped retries;
///              after the cap (3) it auto-promotes to permanent.
/// neither → standard transient (stays pending with exp backoff,
///           uncapped — same shape as before this phase).

Future<String> seedQueueRow(
  AppDatabase db, [
  String actionType = 'orders:upsert',
]) async {
  await db.syncDao.enqueue(actionType, '{"id":"abc"}');
  final pending = await getPendingQueue(db);
  return pending.first.id;
}

void main() {

  group('SyncDao.markFailed (§6.8 failure classes)', () {
    test('permanent failure auto-moves the row to sync_queue_orphans',
        () async {
      final boot = await bootstrapTestDb();
      try {
        final id = await seedQueueRow(boot.db);

        await boot.db.syncDao
            .markFailed(id, '23514: check_violation', permanent: true);

        // Original row removed from sync_queue.
        final remaining = await boot.db.select(boot.db.syncQueue).get();
        expect(remaining, isEmpty,
            reason: 'permanent failures must leave the queue');

        // Archived in sync_queue_orphans with the original id preserved.
        final orphans = await boot.db.select(boot.db.syncQueueOrphans).get();
        expect(orphans, hasLength(1));
        expect(orphans.first.originalId, id);
        expect(orphans.first.actionType, 'orders:upsert');
        expect(orphans.first.reason, '23514: check_violation');
      } finally {
        await boot.db.close();
      }
    });

    test(
        'fkDeferred under the cap stays pending with longer backoff '
        '(>= 5 min)', () async {
      final boot = await bootstrapTestDb();
      try {
        final id = await seedQueueRow(boot.db);
        final before = DateTime.now();

        await boot.db.syncDao.markFailed(
          id,
          '23503: foreign_key_violation',
          fkDeferred: true,
        );

        // Still in queue, status pending, attempts bumped, nextAttemptAt
        // far enough out that another push pass can wedge a pull in
        // between (10-minute base × 2^1 = 20 min; we just check >= 5 min
        // to keep the bound loose).
        final row = await (boot.db.select(boot.db.syncQueue)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.status, 'pending');
        expect(row.attempts, 1);
        expect(row.nextAttemptAt, isNotNull);
        final delay = row.nextAttemptAt!.difference(before);
        expect(delay.inMinutes, greaterThanOrEqualTo(5),
            reason: 'fk-deferred must wait for at least one pull cycle');

        // Orphans table empty — not promoted yet.
        expect(
            await boot.db.select(boot.db.syncQueueOrphans).get(), isEmpty);
      } finally {
        await boot.db.close();
      }
    });

    test('fkDeferred promoted to permanent after the retry cap (3)',
        () async {
      final boot = await bootstrapTestDb();
      try {
        final id = await seedQueueRow(boot.db);

        // 1st + 2nd attempts: deferred, stay pending.
        await boot.db.syncDao
            .markFailed(id, '23503: parent missing', fkDeferred: true);
        await boot.db.syncDao
            .markFailed(id, '23503: parent missing', fkDeferred: true);
        expect(
            await boot.db.select(boot.db.syncQueueOrphans).get(), isEmpty);

        // 3rd attempt: hits the cap → moves to orphans.
        await boot.db.syncDao
            .markFailed(id, '23503: parent missing', fkDeferred: true);

        expect(await boot.db.select(boot.db.syncQueue).get(), isEmpty,
            reason: 'after the cap the row must leave the queue');

        final orphans = await boot.db.select(boot.db.syncQueueOrphans).get();
        expect(orphans, hasLength(1));
        expect(orphans.first.originalId, id);
        expect(orphans.first.reason, contains('fk_deferred_cap_reached'));
      } finally {
        await boot.db.close();
      }
    });

    test(
        'getPendingItems honors nextAttemptAt — failed-with-backoff rows are '
        'skipped until their window opens',
        () async {
      final boot = await bootstrapTestDb();
      try {
        final id = await seedQueueRow(boot.db);
        // Mark as transient failure → row stays pending with
        // nextAttemptAt set ~30s in the future.
        await boot.db.syncDao.markFailed(id, 'network: timeout');

        final immediate = await boot.db.syncDao.getPendingItems();
        expect(
          immediate.any((r) => r.id == id),
          isFalse,
          reason: 'rows scheduled for future retry must NOT come back '
              'on the next push pass — otherwise the exponential backoff '
              '(and FK-deferred 10-min wait) is inert',
        );

        // Roll the row's nextAttemptAt into the past; now it must be
        // returned again.
        await (boot.db.update(boot.db.syncQueue)
              ..where((t) => t.id.equals(id)))
            .write(SyncQueueCompanion(
          nextAttemptAt: Value(DateTime.now().subtract(
            const Duration(seconds: 1),
          )),
        ));
        final afterWindow = await boot.db.syncDao.getPendingItems();
        expect(afterWindow.any((r) => r.id == id), isTrue);
      } finally {
        await boot.db.close();
      }
    });

    test('transient failure (neither permanent nor fkDeferred) stays in queue',
        () async {
      final boot = await bootstrapTestDb();
      try {
        final id = await seedQueueRow(boot.db);

        await boot.db.syncDao.markFailed(id, 'network: timeout');

        final row = await (boot.db.select(boot.db.syncQueue)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        expect(row.status, 'pending');
        expect(row.attempts, 1);
        expect(row.errorMessage, 'network: timeout');
        expect(
            await boot.db.select(boot.db.syncQueueOrphans).get(), isEmpty);
      } finally {
        await boot.db.close();
      }
    });
  });
}

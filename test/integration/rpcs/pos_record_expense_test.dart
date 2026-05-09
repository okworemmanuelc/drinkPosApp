@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

import '../../helpers/supabase_test_clients.dart';
import '../../helpers/supabase_test_env.dart';
import '../../helpers/test_business_fixture.dart';

/// Tier-2 integration tests for the v2 pos_record_expense RPC. Hits real
/// dev Supabase. Auto-skipped when env vars are absent.
///
/// Note on cleanup: `activity_logs` and `payment_transactions` are
/// append-only (the `forbid_delete` trigger raises on DELETE), and they
/// FK into `expenses` with NO ACTION — so the expense parent is also
/// effectively undeleteable while these children exist. Tests leak rows
/// per run into the shared test business. Acceptable for dev-machine
/// integration runs; reset the business periodically if rows accumulate.

final String? _skipReason = (() {
  try {
    TestEnv.load();
    return null;
  } on StateError catch (e) {
    return e.message;
  }
})();

void main() {
  late TestClients clients;
  late TestBusinessFixture fixture;

  setUpAll(() async {
    if (_skipReason != null) return;
    clients = await TestClients.setUp();
    fixture = TestBusinessFixture(clients.adminClient, clients.env.businessId);
  });

  tearDownAll(() async {
    if (_skipReason != null) return;
    await clients.dispose();
  });

  group('pos_record_expense (Tier 2)', () {
    test('round-trip: response shape + cloud rows match', () async {
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      final activityId = UuidV7.generate();

      final response = await clients.userClient.rpc(
        'pos_record_expense',
        params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_expense_id': expenseId,
          'p_payment_id': paymentId,
          'p_activity_log_id': activityId,
          'p_amount_kobo': 75000,
          'p_description': 'Round-trip diesel',
          'p_payment_method': 'cash',
        },
      );

      expect(response, isA<Map>());
      final map = response as Map;
      expect(map['replayed'], isFalse);

      final expense = map['expense'] as Map;
      expect(expense['id'], expenseId);
      expect(expense['amount_kobo'], 75000);
      expect(expense['description'], 'Round-trip diesel');
      expect(expense['is_deleted'], isFalse);

      final activity = map['activity_log'] as Map;
      expect(activity['id'], activityId);
      expect(activity['action'], 'expense_recorded');
      expect(activity['expense_id'], expenseId);

      final payment = map['payment_transaction'] as Map;
      expect(payment['id'], paymentId);
      expect(payment['amount_kobo'], 75000);
      expect(payment['method'], 'cash');
      expect(payment['type'], 'expense');
      expect(payment['expense_id'], expenseId);

      // Cloud-side verification.
      final cloudExp = await clients.adminClient
          .from('expenses')
          .select()
          .eq('id', expenseId)
          .single();
      expect(cloudExp['amount_kobo'], 75000);
      expect(cloudExp['last_updated_at'], expense['last_updated_at']);

      final cloudPay = await clients.adminClient
          .from('payment_transactions')
          .select()
          .eq('id', paymentId)
          .single();
      expect(cloudPay['expense_id'], expenseId);
    }, skip: _skipReason);

    test(
        'round-trip (no payment method): payment_transaction is null, '
        'expense + activity_log still written', () async {
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate(); // unused server-side
      final activityId = UuidV7.generate();

      final response = await clients.userClient.rpc(
        'pos_record_expense',
        params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_expense_id': expenseId,
          'p_payment_id': paymentId,
          'p_activity_log_id': activityId,
          'p_amount_kobo': 1000,
          'p_description': 'Tip jar (no payment method)',
          // p_payment_method omitted → defaults to NULL → RPC skips payment
        },
      );

      final map = response as Map;
      expect(map['expense'], isNotNull);
      expect(map['activity_log'], isNotNull);
      // Documented contract: when p_payment_method is NULL the RPC
      // doesn't insert a payment row, so the response key is null.
      expect(map['payment_transaction'], isNull);

      // Cloud confirms zero payment rows for the supplied id.
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);

    test('replay: second call returns replayed=true; no duplicate rows',
        () async {
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      final activityId = UuidV7.generate();

      Map<String, dynamic> params() => {
            'p_business_id': clients.env.businessId,
            'p_actor_id': clients.env.userId,
            'p_expense_id': expenseId,
            'p_payment_id': paymentId,
            'p_activity_log_id': activityId,
            'p_amount_kobo': 12500,
            'p_description': 'Replay test',
            'p_payment_method': 'transfer',
          };

      final first = await clients.userClient
          .rpc('pos_record_expense', params: params()) as Map;
      expect(first['replayed'], isFalse);

      final second = await clients.userClient
          .rpc('pos_record_expense', params: params()) as Map;
      expect(second['replayed'], isTrue);

      // Exactly one of each row exists for these ids.
      expect(await fixture.countById('expenses', expenseId), 1);
      expect(await fixture.countById('activity_logs', activityId), 1);
      expect(await fixture.countById('payment_transactions', paymentId), 1);
    }, skip: _skipReason);

    test('atomicity (tenant guard): bogus business_id raises, no rows',
        () async {
      final bogus = UuidV7.generate();
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      final activityId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_record_expense', params: {
          'p_business_id': bogus,
          'p_actor_id': clients.env.userId,
          'p_expense_id': expenseId,
          'p_payment_id': paymentId,
          'p_activity_log_id': activityId,
          'p_amount_kobo': 1000,
          'p_description': 'Cross-tenant attempt',
          'p_payment_method': 'cash',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(await fixture.countById('expenses', expenseId), 0);
      expect(await fixture.countById('activity_logs', activityId), 0);
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);

    test('atomicity (validation): zero amount raises, no rows', () async {
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      final activityId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_record_expense', params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_expense_id': expenseId,
          'p_payment_id': paymentId,
          'p_activity_log_id': activityId,
          'p_amount_kobo': 0, // RPC validates amount > 0
          'p_description': 'Zero amount',
          'p_payment_method': 'cash',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull,
          reason: 'amount_must_be_positive guard should fire');
      // All three tables must be empty for these ids — proves the validation
      // raised before any insert ran.
      expect(await fixture.countById('expenses', expenseId), 0);
      expect(await fixture.countById('activity_logs', activityId), 0);
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);

    test(
        'atomicity (mid-body): invalid payment_method rolls back expense + '
        'activity_log', () async {
      final expenseId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      final activityId = UuidV7.generate();

      // 'crypto' is not in the payment_method CHECK list. The RPC inserts
      // expense (success) → activity_log (success) → payment_transactions
      // (CHECK violation). All three must roll back.
      Object? caught;
      try {
        await clients.userClient.rpc('pos_record_expense', params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_expense_id': expenseId,
          'p_payment_id': paymentId,
          'p_activity_log_id': activityId,
          'p_amount_kobo': 1000,
          'p_description': 'Bad payment method',
          'p_payment_method': 'crypto',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull,
          reason: 'payment_method CHECK constraint should fire');
      expect(await fixture.countById('expenses', expenseId), 0,
          reason: 'expense insert must roll back when later step fails');
      expect(await fixture.countById('activity_logs', activityId), 0,
          reason: 'activity_log insert must roll back too');
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);
  });
}

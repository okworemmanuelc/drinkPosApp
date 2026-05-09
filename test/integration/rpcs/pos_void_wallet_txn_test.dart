@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

import '../../helpers/supabase_test_clients.dart';
import '../../helpers/supabase_test_env.dart';
import '../../helpers/test_business_fixture.dart';

/// Tier-2 integration tests for the v2 pos_void_wallet_txn RPC. Hits real
/// dev Supabase. Auto-skipped when env vars are absent.
///
/// Note on cleanup: `wallet_transactions` is append-only — both the
/// original and the compensating rows leak per run. Acceptable for
/// dev-machine integration runs; reset the test business periodically.

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

  // Each test creates its own customer + wallet + parent topup so balances
  // don't tangle between tests.
  final createdCustomerIds = <String>[];

  Future<({String customerId, String walletId, String origTxnId})>
      seedVoidableTopup({int amountKobo = 50000}) async {
    final customerId = UuidV7.generate();
    final walletId = UuidV7.generate();
    await clients.userClient.rpc('pos_create_customer', params: {
      'p_business_id': clients.env.businessId,
      'p_customer_id': customerId,
      'p_wallet_id': walletId,
      'p_name': 'Voidable Vivian',
    });
    createdCustomerIds.add(customerId);

    final origTxnId = UuidV7.generate();
    final paymentId = UuidV7.generate();
    await clients.userClient.rpc('pos_wallet_topup', params: {
      'p_business_id': clients.env.businessId,
      'p_actor_id': clients.env.userId,
      'p_wallet_txn_id': origTxnId,
      'p_payment_id': paymentId,
      'p_customer_id': customerId,
      'p_amount_kobo': amountKobo,
      'p_method': 'cash',
      'p_reference_type': 'topup_cash',
    });

    return (customerId: customerId, walletId: walletId, origTxnId: origTxnId);
  }

  setUpAll(() async {
    if (_skipReason != null) return;
    clients = await TestClients.setUp();
    fixture = TestBusinessFixture(clients.adminClient, clients.env.businessId);
  });

  tearDown(() async {
    if (_skipReason != null) return;
    for (final id in createdCustomerIds) {
      await fixture.deleteCustomerCascade(id);
    }
    createdCustomerIds.clear();
  });

  tearDownAll(() async {
    if (_skipReason != null) return;
    await clients.dispose();
  });

  group('pos_void_wallet_txn (Tier 2)', () {
    test('round-trip: response shape + cloud rows match', () async {
      final s = await seedVoidableTopup(amountKobo: 50000);
      final compId = UuidV7.generate();

      final response = await clients.userClient.rpc(
        'pos_void_wallet_txn',
        params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_original_id': s.origTxnId,
          'p_compensating_id': compId,
          'p_void_reason': 'wrong amount',
        },
      );

      expect(response, isA<Map>());
      final map = response as Map;
      expect(map['replayed'], isFalse);

      final voided = map['voided_transaction'] as Map;
      expect(voided['id'], s.origTxnId);
      expect(voided['voided_at'], isNotNull);
      expect(voided['voided_by'], clients.env.userId);
      expect(voided['void_reason'], 'wrong amount');

      final comp = map['compensating_transaction'] as Map;
      expect(comp['id'], compId);
      // Original was credit/+50000 → compensating is debit/-50000.
      expect(comp['type'], 'debit');
      expect(comp['amount_kobo'], 50000);
      expect(comp['signed_amount_kobo'], -50000);
      expect(comp['reference_type'], 'void');
      expect(comp['wallet_id'], s.walletId);
      expect(comp['customer_id'], s.customerId);

      // Cloud-side verification.
      final cloudOrig = await clients.adminClient
          .from('wallet_transactions')
          .select()
          .eq('id', s.origTxnId)
          .single();
      expect(cloudOrig['voided_at'], isNotNull);
      expect(cloudOrig['last_updated_at'], voided['last_updated_at']);

      final cloudComp = await clients.adminClient
          .from('wallet_transactions')
          .select()
          .eq('id', compId)
          .single();
      expect(cloudComp['signed_amount_kobo'], -50000);
      expect(cloudComp['reference_type'], 'void');
    }, skip: _skipReason);

    test('replay: second call returns replayed=true; no second compensating',
        () async {
      final s = await seedVoidableTopup(amountKobo: 25000);
      final compId = UuidV7.generate();

      Map<String, dynamic> params() => {
            'p_business_id': clients.env.businessId,
            'p_actor_id': clients.env.userId,
            'p_original_id': s.origTxnId,
            'p_compensating_id': compId,
            'p_void_reason': 'replay test',
          };

      final first = await clients.userClient
          .rpc('pos_void_wallet_txn', params: params()) as Map;
      expect(first['replayed'], isFalse);

      final second = await clients.userClient
          .rpc('pos_void_wallet_txn', params: params()) as Map;
      expect(second['replayed'], isTrue);

      // Exactly one compensating row in cloud.
      final compRows = await clients.adminClient
          .from('wallet_transactions')
          .select('id')
          .eq('id', compId);
      expect(compRows, hasLength(1),
          reason: 'replay must not append a second compensating entry');

      // Customer's wallet ledger has exactly two rows: original + comp.
      final allRows = await clients.adminClient
          .from('wallet_transactions')
          .select('id')
          .eq('customer_id', s.customerId);
      expect(allRows, hasLength(2));
    }, skip: _skipReason);

    test('atomicity (tenant guard): bogus business_id raises, no rows',
        () async {
      final bogus = UuidV7.generate();
      final compId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_void_wallet_txn', params: {
          'p_business_id': bogus,
          'p_actor_id': clients.env.userId,
          'p_original_id': UuidV7.generate(),
          'p_compensating_id': compId,
          'p_void_reason': 'cross-tenant attempt',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(await fixture.countById('wallet_transactions', compId), 0);
    }, skip: _skipReason);

    test('atomicity (validation): missing original raises, no compensating',
        () async {
      final compId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_void_wallet_txn', params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          // No such row in this business.
          'p_original_id': UuidV7.generate(),
          'p_compensating_id': compId,
          'p_void_reason': 'phantom original',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull,
          reason: 'wallet_txn_not_found guard should fire');
      expect(await fixture.countById('wallet_transactions', compId), 0,
          reason: 'no compensating row may be inserted when original is absent');
    }, skip: _skipReason);
  });
}

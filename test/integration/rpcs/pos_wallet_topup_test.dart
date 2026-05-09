@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

import '../../helpers/supabase_test_clients.dart';
import '../../helpers/supabase_test_env.dart';
import '../../helpers/test_business_fixture.dart';

/// Tier-2 integration tests for the v2 pos_wallet_topup RPC. Hits real dev
/// Supabase. Auto-skipped when env vars are absent.

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

  // Each topup test creates a fresh customer+wallet so we don't tangle with
  // wallet balances from other tests. Tracked here for cleanup.
  final createdCustomerIds = <String>[];
  final createdTopups = <({String walletTxnId, String paymentId})>[];

  Future<({String customerId, String walletId})> seedCustomer() async {
    final customerId = UuidV7.generate();
    final walletId = UuidV7.generate();
    await clients.userClient.rpc('pos_create_customer', params: {
      'p_business_id': clients.env.businessId,
      'p_customer_id': customerId,
      'p_wallet_id': walletId,
      'p_name': 'Topup Test Customer',
    });
    createdCustomerIds.add(customerId);
    return (customerId: customerId, walletId: walletId);
  }

  setUpAll(() async {
    if (_skipReason != null) return;
    clients = await TestClients.setUp();
    fixture = TestBusinessFixture(clients.adminClient, clients.env.businessId);
  });

  tearDown(() async {
    if (_skipReason != null) return;
    for (final t in createdTopups) {
      await fixture.deleteTopupRows(
        walletTxnId: t.walletTxnId,
        paymentId: t.paymentId,
      );
    }
    createdTopups.clear();
    for (final id in createdCustomerIds) {
      await fixture.deleteCustomerCascade(id);
    }
    createdCustomerIds.clear();
  });

  tearDownAll(() async {
    if (_skipReason != null) return;
    await clients.dispose();
  });

  group('pos_wallet_topup (Tier 2)', () {
    test('round-trip: response shape + cloud rows match', () async {
      final c = await seedCustomer();
      final walletTxnId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      createdTopups.add((walletTxnId: walletTxnId, paymentId: paymentId));

      final response = await clients.userClient.rpc(
        'pos_wallet_topup',
        params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_wallet_txn_id': walletTxnId,
          'p_payment_id': paymentId,
          'p_customer_id': c.customerId,
          'p_amount_kobo': 50000,
          'p_method': 'cash',
          'p_reference_type': 'topup_cash',
        },
      );

      expect(response, isA<Map>());
      final map = response as Map;
      expect(map['replayed'], isFalse);

      final wt = map['wallet_transaction'] as Map;
      expect(wt['id'], walletTxnId);
      expect(wt['type'], 'credit');
      expect(wt['amount_kobo'], 50000);
      expect(wt['signed_amount_kobo'], 50000);
      expect(wt['reference_type'], 'topup_cash');
      expect(wt['customer_id'], c.customerId);
      expect(wt['wallet_id'], c.walletId);
      expect(wt['voided_at'], isNull);

      final pt = map['payment_transaction'] as Map;
      expect(pt['id'], paymentId);
      expect(pt['amount_kobo'], 50000);
      expect(pt['method'], 'cash');
      expect(pt['type'], 'wallet_topup');
      expect(pt['wallet_txn_id'], walletTxnId);

      // Cloud-side verification.
      final cloudWt = await clients.adminClient
          .from('wallet_transactions')
          .select()
          .eq('id', walletTxnId)
          .single();
      expect(cloudWt['signed_amount_kobo'], 50000);
      expect(cloudWt['last_updated_at'], wt['last_updated_at']);

      final cloudPt = await clients.adminClient
          .from('payment_transactions')
          .select()
          .eq('id', paymentId)
          .single();
      expect(cloudPt['amount_kobo'], 50000);
    }, skip: _skipReason);

    test('replay: second call returns replayed=true; no duplicate ledger row',
        () async {
      final c = await seedCustomer();
      final walletTxnId = UuidV7.generate();
      final paymentId = UuidV7.generate();
      createdTopups.add((walletTxnId: walletTxnId, paymentId: paymentId));

      Map<String, dynamic> params() => {
            'p_business_id': clients.env.businessId,
            'p_actor_id': clients.env.userId,
            'p_wallet_txn_id': walletTxnId,
            'p_payment_id': paymentId,
            'p_customer_id': c.customerId,
            'p_amount_kobo': 25000,
            'p_method': 'transfer',
            'p_reference_type': 'topup_transfer',
          };

      final first = await clients.userClient
          .rpc('pos_wallet_topup', params: params()) as Map;
      expect(first['replayed'], isFalse);

      final second = await clients.userClient
          .rpc('pos_wallet_topup', params: params()) as Map;
      expect(second['replayed'], isTrue);

      // Exactly one wallet txn and one payment txn cloud-side. Crucially,
      // no second debit/credit means the customer's balance isn't doubled
      // by a retry storm.
      final cloudWt = await clients.adminClient
          .from('wallet_transactions')
          .select('id')
          .eq('customer_id', c.customerId);
      expect(cloudWt, hasLength(1),
          reason: 'replay must not append a second wallet ledger entry');

      final cloudPt = await clients.adminClient
          .from('payment_transactions')
          .select('id')
          .eq('id', paymentId);
      expect(cloudPt, hasLength(1));
    }, skip: _skipReason);

    test('atomicity (tenant guard): bogus business_id raises, no rows',
        () async {
      final bogus = UuidV7.generate();
      final walletTxnId = UuidV7.generate();
      final paymentId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_wallet_topup', params: {
          'p_business_id': bogus,
          'p_actor_id': clients.env.userId,
          'p_wallet_txn_id': walletTxnId,
          'p_payment_id': paymentId,
          'p_customer_id': UuidV7.generate(),
          'p_amount_kobo': 10000,
          'p_method': 'cash',
          'p_reference_type': 'topup_cash',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(await fixture.countById('wallet_transactions', walletTxnId), 0);
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);

    test('atomicity (validation): zero amount raises, no rows', () async {
      final c = await seedCustomer();
      final walletTxnId = UuidV7.generate();
      final paymentId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_wallet_topup', params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_wallet_txn_id': walletTxnId,
          'p_payment_id': paymentId,
          'p_customer_id': c.customerId,
          'p_amount_kobo': 0, // RPC validates amount > 0
          'p_method': 'cash',
          'p_reference_type': 'topup_cash',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull,
          reason: 'amount_must_be_positive guard should fire');
      expect(await fixture.countById('wallet_transactions', walletTxnId), 0);
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);

    test('atomicity (validation): customer with no wallet raises, no rows',
        () async {
      final orphanCustomerId = UuidV7.generate();
      // Insert a customer WITHOUT creating a wallet, via service role.
      await clients.adminClient.from('customers').insert({
        'id': orphanCustomerId,
        'business_id': clients.env.businessId,
        'name': 'Walletless Wendy',
      });
      createdCustomerIds.add(orphanCustomerId);

      final walletTxnId = UuidV7.generate();
      final paymentId = UuidV7.generate();

      Object? caught;
      try {
        await clients.userClient.rpc('pos_wallet_topup', params: {
          'p_business_id': clients.env.businessId,
          'p_actor_id': clients.env.userId,
          'p_wallet_txn_id': walletTxnId,
          'p_payment_id': paymentId,
          'p_customer_id': orphanCustomerId,
          'p_amount_kobo': 1000,
          'p_method': 'cash',
          'p_reference_type': 'topup_cash',
        });
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull,
          reason: 'customer_wallet_missing guard should fire');
      expect(await fixture.countById('wallet_transactions', walletTxnId), 0);
      expect(await fixture.countById('payment_transactions', paymentId), 0);
    }, skip: _skipReason);
  });
}

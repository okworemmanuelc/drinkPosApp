import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database_helper.dart';
import '../../../features/customers/data/models/customer.dart';
import '../../../features/customers/data/models/payment.dart';

class CustomerRepository {
  Future<List<Customer>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'customers',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    final customers = <Customer>[];
    for (final row in rows) {
      customers.add(await _fromRow(db, row));
    }
    return customers;
  }

  Future<void> insert(Customer c) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('customers', {
      'id': c.id,
      'name': c.name,
      'address_text': c.addressText,
      'google_maps_location': c.googleMapsLocation,
      'phone': c.phone,
      'customer_wallet': c.customerWallet,
      'wallet_limit': c.walletLimit,
      'customer_group': c.customerGroup.name,
      'is_walk_in': c.isWalkIn ? 1 : 0,
      'created_at': c.createdAt.toIso8601String(),
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
    await _savePayments(db, c.id, c.payments, now);
    await _saveCrateBalances(db, c.id, c.emptyCratesBalance, now);
  }

  Future<void> update(Customer c) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'customers',
      {
        'name': c.name,
        'address_text': c.addressText,
        'google_maps_location': c.googleMapsLocation,
        'phone': c.phone,
        'customer_wallet': c.customerWallet,
        'wallet_limit': c.walletLimit,
        'customer_group': c.customerGroup.name,
        'is_walk_in': c.isWalkIn ? 1 : 0,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
    await _savePayments(db, c.id, c.payments, now);
    await _saveCrateBalances(db, c.id, c.emptyCratesBalance, now);
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'customers',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- helpers ---

  Future<void> _savePayments(dynamic db, String customerId, List<Payment> payments, String now) async {
    await db.delete('customer_payments', where: 'customer_id = ?', whereArgs: [customerId]);
    for (final p in payments) {
      await db.insert('customer_payments', {
        'id': p.id,
        'customer_id': customerId,
        'amount': p.amount,
        'timestamp': p.timestamp.toIso8601String(),
        'note': p.note,
        'synced': 0,
        'updated_at': now,
        'deleted_at': null,
      });
    }
  }

  Future<void> _saveCrateBalances(dynamic db, String customerId, Map<String, int> balances, String now) async {
    for (final entry in balances.entries) {
      await db.insert(
        'customer_crate_balances',
        {
          'customer_id': customerId,
          'crate_group': entry.key,
          'qty': entry.value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // REPLACE
      );
    }
  }

  Future<Customer> _fromRow(dynamic db, Map<String, dynamic> row) async {
    final id = row['id'] as String;

    final payRows = await db.query(
      'customer_payments',
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    final payments = payRows.map((r) => Payment(
      id: r['id'] as String,
      amount: (r['amount'] as num).toDouble(),
      timestamp: DateTime.parse(r['timestamp'] as String),
      note: r['note'] as String?,
    )).toList();

    final crateRows = await db.query(
      'customer_crate_balances',
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    final crateBalance = <String, int>{
      for (final r in crateRows) r['crate_group'] as String: (r['qty'] as num).toInt(),
    };

    final groupStr = row['customer_group'] as String? ?? 'retailer';
    final group = CustomerGroup.values.firstWhere(
      (g) => g.name == groupStr,
      orElse: () => CustomerGroup.retailer,
    );

    return Customer(
      id: id,
      name: row['name'] as String,
      addressText: row['address_text'] as String,
      googleMapsLocation: row['google_maps_location'] as String,
      phone: row['phone'] as String?,
      customerWallet: (row['customer_wallet'] as num).toDouble(),
      walletLimit: (row['wallet_limit'] as num).toDouble(),
      emptyCratesBalance: crateBalance,
      payments: payments,
      customerGroup: group,
      isWalkIn: (row['is_walk_in'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Returns all rows with synced = 0 as raw maps (for SyncService)
  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('customers', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update(
      'customers',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Upsert a raw row coming from Supabase (already remote format)
  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert(
      'customers',
      {...row, 'synced': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

final customerRepository = CustomerRepository();

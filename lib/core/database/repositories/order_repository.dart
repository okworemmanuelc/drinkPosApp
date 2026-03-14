import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../../../shared/models/order.dart';

const _uuid = Uuid();

class OrderRepository {
  Future<List<Order>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'orders',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    final orders = <Order>[];
    for (final row in rows) {
      orders.add(await _fromRow(db, row));
    }
    return orders;
  }

  Future<void> insert(Order o) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('orders', {
      'id': o.id,
      'customer_id': o.customerId,
      'customer_name': o.customerName,
      'customer_address': o.customerAddress,
      'customer_phone': o.customerPhone,
      'subtotal': o.subtotal,
      'crate_deposit': o.crateDeposit,
      'total_amount': o.totalAmount,
      'amount_paid': o.amountPaid,
      'customer_wallet': o.customerWallet,
      'payment_method': o.paymentMethod,
      'created_at': o.createdAt.toIso8601String(),
      'completed_at': o.completedAt?.toIso8601String(),
      'status': o.status,
      'rider_name': o.riderName,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
    await _saveItems(db, o.id, o.items);
    await _saveReprints(db, o.id, o.reprints);
  }

  Future<void> update(Order o) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'orders',
      {
        'customer_id': o.customerId,
        'customer_name': o.customerName,
        'customer_address': o.customerAddress,
        'customer_phone': o.customerPhone,
        'subtotal': o.subtotal,
        'crate_deposit': o.crateDeposit,
        'total_amount': o.totalAmount,
        'amount_paid': o.amountPaid,
        'customer_wallet': o.customerWallet,
        'payment_method': o.paymentMethod,
        'completed_at': o.completedAt?.toIso8601String(),
        'status': o.status,
        'rider_name': o.riderName,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [o.id],
    );
    await _saveItems(db, o.id, o.items);
    await _saveReprints(db, o.id, o.reprints);
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'orders',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('orders', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('orders', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('orders', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- helpers ---

  Future<void> _saveItems(dynamic db, String orderId, List<Map<String, dynamic>> items) async {
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    for (final item in items) {
      await db.insert('order_items', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'product_name': item['name'] ?? '',
        'subtitle': item['subtitle'],
        'price': (item['price'] as num?)?.toDouble() ?? 0.0,
        'qty': (item['qty'] as num?)?.toDouble() ?? 0.0,
        'category': item['category'],
        'crate_group_name': item['crateGroupName'],
        'needs_empty_crate': (item['needsEmptyCrate'] == true) ? 1 : 0,
      });
    }
  }

  Future<void> _saveReprints(dynamic db, String orderId, List<DateTime> reprints) async {
    await db.delete('order_reprints', where: 'order_id = ?', whereArgs: [orderId]);
    for (final dt in reprints) {
      await db.insert('order_reprints', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'reprinted_at': dt.toIso8601String(),
      });
    }
  }

  Future<Order> _fromRow(dynamic db, Map<String, dynamic> row) async {
    final id = row['id'] as String;

    final itemRows = await db.query('order_items', where: 'order_id = ?', whereArgs: [id]);
    final items = itemRows.map((r) => {
      'name': r['product_name'],
      'subtitle': r['subtitle'],
      'price': r['price'],
      'qty': r['qty'],
      'category': r['category'],
      'crateGroupName': r['crate_group_name'],
      'needsEmptyCrate': (r['needs_empty_crate'] as int) == 1,
    }).toList();

    final reprintRows = await db.query('order_reprints', where: 'order_id = ?', whereArgs: [id]);
    final reprints = reprintRows
        .map((r) => DateTime.parse(r['reprinted_at'] as String))
        .toList();

    return Order(
      id: id,
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name'] as String,
      customerAddress: row['customer_address'] as String? ?? '',
      customerPhone: row['customer_phone'] as String? ?? '',
      items: items,
      subtotal: (row['subtotal'] as num).toDouble(),
      crateDeposit: (row['crate_deposit'] as num).toDouble(),
      totalAmount: (row['total_amount'] as num).toDouble(),
      amountPaid: (row['amount_paid'] as num).toDouble(),
      customerWallet: (row['customer_wallet'] as num).toDouble(),
      paymentMethod: row['payment_method'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      status: row['status'] as String? ?? 'pending',
      reprints: reprints,
      riderName: row['rider_name'] as String? ?? 'Pick-up Order',
    );
  }
}

final orderRepository = OrderRepository();

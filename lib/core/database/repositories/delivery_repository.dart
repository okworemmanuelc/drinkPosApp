import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../../../features/deliveries/data/models/delivery.dart';
import '../../../features/deliveries/data/models/delivery_receipt.dart';

const _uuid = Uuid();

class DeliveryRepository {
  Future<List<Delivery>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'deliveries',
      where: 'deleted_at IS NULL',
      orderBy: 'delivered_at DESC',
    );
    final result = <Delivery>[];
    for (final row in rows) {
      result.add(await _fromRow(db, row));
    }
    return result;
  }

  Future<void> insert(Delivery d) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('deliveries', {
      'id': d.id,
      'supplier_name': d.supplierName,
      'delivered_at': d.deliveredAt.toIso8601String(),
      'total_value': d.totalValue,
      'status': d.status,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
    await _saveItems(db, d.id, d.items);
  }

  Future<void> update(Delivery d) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'deliveries',
      {
        'supplier_name': d.supplierName,
        'delivered_at': d.deliveredAt.toIso8601String(),
        'total_value': d.totalValue,
        'status': d.status,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [d.id],
    );
    await _saveItems(db, d.id, d.items);
  }

  Future<void> insertReceipt(DeliveryReceipt r) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('delivery_receipts', {
      'id': r.id,
      'order_id': r.orderId,
      'reference_number': r.referenceNumber,
      'rider_name': r.riderName,
      'outstanding_amount': r.outstandingAmount,
      'paid_amount': r.paidAmount,
      'created_at': r.createdAt.toIso8601String(),
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('deliveries', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('deliveries', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('deliveries', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveItems(dynamic db, String deliveryId, List<DeliveryItem> items) async {
    await db.delete('delivery_items', where: 'delivery_id = ?', whereArgs: [deliveryId]);
    for (final item in items) {
      await db.insert('delivery_items', {
        'id': _uuid.v4(),
        'delivery_id': deliveryId,
        'product_id': item.productId,
        'product_name': item.productName,
        'supplier_name': item.supplierName,
        'crate_group_label': item.crateGroupLabel,
        'unit_price': item.unitPrice,
        'quantity': item.quantity,
      });
    }
  }

  Future<Delivery> _fromRow(dynamic db, Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final itemRows = await db.query('delivery_items', where: 'delivery_id = ?', whereArgs: [id]);
    final items = itemRows.map((r) => DeliveryItem(
      productId: r['product_id'] as String? ?? '',
      productName: r['product_name'] as String,
      supplierName: r['supplier_name'] as String,
      crateGroupLabel: r['crate_group_label'] as String?,
      unitPrice: (r['unit_price'] as num).toDouble(),
      quantity: (r['quantity'] as num).toDouble(),
    )).toList();

    return Delivery(
      id: id,
      supplierName: row['supplier_name'] as String,
      deliveredAt: DateTime.parse(row['delivered_at'] as String),
      items: items,
      totalValue: (row['total_value'] as num).toDouble(),
      status: row['status'] as String? ?? 'pending',
    );
  }
}

final deliveryRepository = DeliveryRepository();

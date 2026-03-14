import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database_helper.dart';
import '../../../features/payments/data/models/payment.dart';

class PaymentRepository {
  Future<List<Payment>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'supplier_payments',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Payment p) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('supplier_payments', {
      'id': p.id,
      'supplier_id': p.supplierId,
      'supplier_name': p.supplierName,
      'amount': p.amount,
      'payment_method': p.paymentMethod,
      'reference_number': p.referenceNumber,
      'notes': p.notes,
      'delivery_id': p.deliveryId,
      'date': p.date.toIso8601String(),
      'created_at': p.createdAt.toIso8601String(),
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'supplier_payments',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('supplier_payments', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('supplier_payments', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('supplier_payments', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Payment _fromRow(Map<String, dynamic> r) => Payment(
    id: r['id'] as String,
    supplierId: r['supplier_id'] as String?,
    supplierName: r['supplier_name'] as String,
    amount: (r['amount'] as num).toDouble(),
    paymentMethod: r['payment_method'] as String,
    referenceNumber: r['reference_number'] as String?,
    notes: r['notes'] as String?,
    deliveryId: r['delivery_id'] as String?,
    date: DateTime.parse(r['date'] as String),
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}

final paymentRepository = PaymentRepository();

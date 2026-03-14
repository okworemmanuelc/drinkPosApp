import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database_helper.dart';
import '../../../features/expenses/data/models/expense.dart';

class ExpenseRepository {
  Future<List<Expense>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'expenses',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Expense e) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('expenses', {
      'id': e.id,
      'category': e.category,
      'amount': e.amount,
      'payment_method': e.paymentMethod,
      'description': e.description,
      'date': e.date.toIso8601String(),
      'created_at': e.createdAt.toIso8601String(),
      'recorded_by': e.recordedBy,
      'reference': e.reference,
      'receipt_path': e.receiptPath,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'expenses',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('expenses', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('expenses', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('expenses', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Expense _fromRow(Map<String, dynamic> r) => Expense(
    id: r['id'] as String,
    category: r['category'] as String,
    amount: (r['amount'] as num).toDouble(),
    paymentMethod: r['payment_method'] as String,
    description: r['description'] as String?,
    date: DateTime.parse(r['date'] as String),
    createdAt: DateTime.parse(r['created_at'] as String),
    recordedBy: r['recorded_by'] as String,
    reference: r['reference'] as String?,
    receiptPath: r['receipt_path'] as String?,
  );
}

final expenseRepository = ExpenseRepository();

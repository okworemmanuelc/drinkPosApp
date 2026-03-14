import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database_helper.dart';
import '../../../features/inventory/data/models/supplier.dart';
import '../../../features/inventory/data/models/crate_group.dart';

class SupplierRepository {
  Future<List<Supplier>> getAll() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('suppliers', where: 'deleted_at IS NULL');
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Supplier s) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('suppliers', {
      'id': s.id,
      'name': s.name,
      'crate_group': s.crateGroup.name,
      'track_inventory': s.trackInventory ? 1 : 0,
      'contact_details': s.contactDetails,
      'amount_paid': s.amountPaid,
      'supplier_wallet': s.supplierWallet,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<void> update(Supplier s) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'suppliers',
      {
        'name': s.name,
        'crate_group': s.crateGroup.name,
        'track_inventory': s.trackInventory ? 1 : 0,
        'contact_details': s.contactDetails,
        'amount_paid': s.amountPaid,
        'supplier_wallet': s.supplierWallet,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'suppliers',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('suppliers', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('suppliers', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemote(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('suppliers', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Supplier _fromRow(Map<String, dynamic> r) {
    final cgStr = r['crate_group'] as String?;
    final cg = CrateGroup.values.firstWhere(
      (g) => g.name == cgStr,
      orElse: () => CrateGroup.nbPlc,
    );
    return Supplier(
      id: r['id'] as String,
      name: r['name'] as String,
      crateGroup: cg,
      trackInventory: (r['track_inventory'] as int) == 1,
      contactDetails: r['contact_details'] as String? ?? '',
      amountPaid: (r['amount_paid'] as num).toDouble(),
      supplierWallet: (r['supplier_wallet'] as num).toDouble(),
    );
  }
}

final supplierRepository = SupplierRepository();

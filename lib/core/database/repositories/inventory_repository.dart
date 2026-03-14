import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database_helper.dart';
import '../../../features/inventory/data/models/inventory_item.dart';
import '../../../features/warehouse/data/models/warehouse.dart';
import '../../../features/inventory/data/models/crate_stock.dart';
import '../../../features/inventory/data/models/crate_group.dart';

class InventoryRepository {
  // ── InventoryItems ──────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getAllItems() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('inventory_items', where: 'deleted_at IS NULL');
    final items = <InventoryItem>[];
    for (final row in rows) {
      items.add(await _itemFromRow(db, row));
    }
    return items;
  }

  Future<void> insertItem(InventoryItem item) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('inventory_items', {
      'id': item.id,
      'product_name': item.productName,
      'subtitle': item.subtitle,
      'supplier_id': item.supplierId,
      'crate_group_name': item.crateGroupName,
      'needs_empty_crate': item.needsEmptyCrate ? 1 : 0,
      'icon_name': _iconToName(item.icon),
      'color_hex': _colorToHex(item.color),
      'low_stock_threshold': item.lowStockThreshold,
      'selling_price': item.sellingPrice,
      'buying_price': item.buyingPrice,
      'retail_price': item.retailPrice,
      'bulk_breaker_price': item.bulkBreakerPrice,
      'distributor_price': item.distributorPrice,
      'category': item.category,
      'paired_crate_item_id': item.pairedCrateItemId,
      'image_path': item.imagePath,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
    await _saveWarehouseStock(db, item.id, item.warehouseStock, now);
  }

  Future<void> updateItem(InventoryItem item) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'inventory_items',
      {
        'product_name': item.productName,
        'subtitle': item.subtitle,
        'supplier_id': item.supplierId,
        'crate_group_name': item.crateGroupName,
        'needs_empty_crate': item.needsEmptyCrate ? 1 : 0,
        'icon_name': _iconToName(item.icon),
        'color_hex': _colorToHex(item.color),
        'low_stock_threshold': item.lowStockThreshold,
        'selling_price': item.sellingPrice,
        'buying_price': item.buyingPrice,
        'retail_price': item.retailPrice,
        'bulk_breaker_price': item.bulkBreakerPrice,
        'distributor_price': item.distributorPrice,
        'category': item.category,
        'paired_crate_item_id': item.pairedCrateItemId,
        'image_path': item.imagePath,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _saveWarehouseStock(db, item.id, item.warehouseStock, now);
  }

  Future<void> deleteItem(String id) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'inventory_items',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Warehouses ───────────────────────────────────────────────────────────────

  Future<List<Warehouse>> getAllWarehouses() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('warehouses', where: 'deleted_at IS NULL');
    return rows.map((r) => Warehouse(
      id: r['id'] as String,
      name: r['name'] as String,
      location: r['location'] as String,
    )).toList();
  }

  Future<void> insertWarehouse(Warehouse w) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert('warehouses', {
      'id': w.id,
      'name': w.name,
      'location': w.location,
      'synced': 0,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  // ── CrateStocks ──────────────────────────────────────────────────────────────

  Future<List<CrateStock>> getAllCrateStocks() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('crate_stocks', where: 'deleted_at IS NULL');
    return rows.map((r) {
      final groupStr = r['crate_group'] as String;
      final group = CrateGroup.values.firstWhere(
        (g) => g.name == groupStr,
        orElse: () => CrateGroup.nbPlc,
      );
      return CrateStock(
        group: group,
        available: (r['available'] as num).toDouble(),
        customLabel: r['custom_label'] as String?,
      );
    }).toList();
  }

  Future<void> upsertCrateStock(CrateStock cs) async {
    final db = await DatabaseHelper.instance.db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'crate_stocks',
      {
        'crate_group': cs.group.name,
        'available': cs.available,
        'custom_label': cs.customLabel,
        'synced': 0,
        'updated_at': now,
        'deleted_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Sync helpers ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUnsyncedItems() async {
    final db = await DatabaseHelper.instance.db;
    return db.query('inventory_items', where: 'synced = 0');
  }

  Future<void> markItemSynced(String id) async {
    final db = await DatabaseHelper.instance.db;
    await db.update('inventory_items', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRemoteItem(Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.db;
    await db.insert('inventory_items', {...row, 'synced': 1}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _saveWarehouseStock(dynamic db, String itemId, Map<String, double> stock, String now) async {
    for (final entry in stock.entries) {
      await db.insert(
        'warehouse_stock',
        {'item_id': itemId, 'warehouse_id': entry.key, 'qty': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<InventoryItem> _itemFromRow(dynamic db, Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final stockRows = await db.query(
      'warehouse_stock',
      where: 'item_id = ?',
      whereArgs: [id],
    );
    final warehouseStock = <String, double>{
      for (final r in stockRows)
        r['warehouse_id'] as String: (r['qty'] as num).toDouble(),
    };

    return InventoryItem(
      id: id,
      productName: row['product_name'] as String,
      subtitle: row['subtitle'] as String,
      supplierId: row['supplier_id'] as String?,
      crateGroupName: row['crate_group_name'] as String?,
      needsEmptyCrate: (row['needs_empty_crate'] as int) == 1,
      icon: _nameToIcon(row['icon_name'] as String? ?? ''),
      color: _hexToColor(row['color_hex'] as String? ?? 'FF607D8B'),
      warehouseStock: warehouseStock,
      lowStockThreshold: (row['low_stock_threshold'] as num).toDouble(),
      sellingPrice: row['selling_price'] != null ? (row['selling_price'] as num).toDouble() : null,
      buyingPrice: row['buying_price'] != null ? (row['buying_price'] as num).toDouble() : null,
      retailPrice: row['retail_price'] != null ? (row['retail_price'] as num).toDouble() : null,
      bulkBreakerPrice: row['bulk_breaker_price'] != null ? (row['bulk_breaker_price'] as num).toDouble() : null,
      distributorPrice: row['distributor_price'] != null ? (row['distributor_price'] as num).toDouble() : null,
      category: row['category'] as String?,
      pairedCrateItemId: row['paired_crate_item_id'] as String?,
      imagePath: row['image_path'] as String?,
    );
  }

  String _colorToHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

  Color _hexToColor(String hex) =>
      Color(int.parse(hex, radix: 16));

  String _iconToName(IconData icon) {
    // Map common FontAwesome icons to string identifiers
    const map = <int, String>{
      0xf0fc: 'beer',
      0xf000: 'beerMugEmpty',
      0xf4e3: 'wineBottle',
      0xf072: 'plane',
      0xf06c: 'leaf',
      0xf7df: 'glassWater',
      0xf000b: 'bottleWater',
    };
    return map[icon.codePoint] ?? icon.codePoint.toString();
  }

  IconData _nameToIcon(String name) {
    const map = <String, IconData>{
      'beer': FontAwesomeIcons.beerMugEmpty,
      'beerMugEmpty': FontAwesomeIcons.beerMugEmpty,
      'wineBottle': FontAwesomeIcons.wineBottle,
      'glassWater': FontAwesomeIcons.glassWater,
      'bottleWater': FontAwesomeIcons.bottleWater,
    };
    if (map.containsKey(name)) return map[name]!;
    // Fallback: try to parse codePoint
    final codePoint = int.tryParse(name);
    if (codePoint != null) return IconData(codePoint, fontFamily: 'FontAwesomeSolid', fontPackage: 'font_awesome_flutter');
    return FontAwesomeIcons.beerMugEmpty;
  }
}

final inventoryRepository = InventoryRepository();

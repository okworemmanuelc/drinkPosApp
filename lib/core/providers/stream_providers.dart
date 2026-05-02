/// Shared Drift stream providers.
///
/// Multiple screens that watch the same data share a single stream
/// automatically — Riverpod deduplicates by provider identity.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

// ── Orders ──────────────────────────────────────────────────────────────────
final allOrdersProvider = StreamProvider<List<OrderWithItems>>((ref) {
  return ref.watch(orderServiceProvider).watchAllOrdersWithItems();
});

// ── Warehouses ──────────────────────────────────────────────────────────────
final allWarehousesProvider = StreamProvider<List<WarehouseData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.warehouses).watch();
});

// ── Expenses ───────────────────────────────────────────────────────────────
final allExpensesProvider = StreamProvider<List<ExpenseWithCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchAll();
});


/// Map of expense category id → name. Resolves the category text for display
/// after the cached `expenses.category` column was removed.
final expenseCategoryNamesProvider =
    StreamProvider<Map<String, String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao
      .watchAllCategories()
      .map((cats) => {for (final c in cats) c.id: c.name});
});

// ── Products by warehouse ───────────────────────────────────────────────────
final productsByWarehouseProvider =
    StreamProvider.family<List<ProductDataWithStock>, String>((ref, warehouseId) {
  return ref
      .watch(databaseProvider)
      .inventoryDao
      .watchProductDatasWithStockByWarehouse(warehouseId);
});

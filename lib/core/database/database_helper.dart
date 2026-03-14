import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  static Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> init() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _db = await _open();
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'onafia_pos.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createWarehouses);
    await db.execute(_createInventoryItems);
    await db.execute(_createWarehouseStock);
    await db.execute(_createCrateStocks);
    await db.execute(_createSuppliers);
    await db.execute(_createCustomers);
    await db.execute(_createCustomerPayments);
    await db.execute(_createCustomerCrateBalances);
    await db.execute(_createOrders);
    await db.execute(_createOrderItems);
    await db.execute(_createOrderReprints);
    await db.execute(_createExpenses);
    await db.execute(_createDeliveries);
    await db.execute(_createDeliveryItems);
    await db.execute(_createDeliveryReceipts);
    await db.execute(_createSupplierPayments);
    await db.execute(_createInventoryLogs);
    await db.execute(_createActivityLogs);
    await db.execute(_createNotifications);
    await db.execute(_createStaff);
    await db.execute(_createSyncMeta);
  }

  static const _syncCols = '''
    synced    INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL,
    deleted_at TEXT
  ''';

  static const _createWarehouses = '''
    CREATE TABLE IF NOT EXISTS warehouses (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      location    TEXT NOT NULL,
      $_syncCols
    )
  ''';

  static const _createInventoryItems = '''
    CREATE TABLE IF NOT EXISTS inventory_items (
      id                    TEXT PRIMARY KEY,
      product_name          TEXT NOT NULL,
      subtitle              TEXT NOT NULL,
      supplier_id           TEXT,
      crate_group_name      TEXT,
      needs_empty_crate     INTEGER NOT NULL DEFAULT 0,
      icon_name             TEXT NOT NULL,
      color_hex             TEXT NOT NULL,
      low_stock_threshold   REAL NOT NULL DEFAULT 5,
      selling_price         REAL,
      buying_price          REAL,
      retail_price          REAL,
      bulk_breaker_price    REAL,
      distributor_price     REAL,
      category              TEXT,
      paired_crate_item_id  TEXT,
      image_path            TEXT,
      $_syncCols
    )
  ''';

  static const _createWarehouseStock = '''
    CREATE TABLE IF NOT EXISTS warehouse_stock (
      item_id       TEXT NOT NULL,
      warehouse_id  TEXT NOT NULL,
      qty           REAL NOT NULL DEFAULT 0,
      updated_at    TEXT NOT NULL,
      PRIMARY KEY (item_id, warehouse_id)
    )
  ''';

  static const _createCrateStocks = '''
    CREATE TABLE IF NOT EXISTS crate_stocks (
      crate_group   TEXT PRIMARY KEY,
      available     REAL NOT NULL DEFAULT 0,
      custom_label  TEXT,
      $_syncCols
    )
  ''';

  static const _createSuppliers = '''
    CREATE TABLE IF NOT EXISTS suppliers (
      id                TEXT PRIMARY KEY,
      name              TEXT NOT NULL,
      crate_group       TEXT,
      track_inventory   INTEGER NOT NULL DEFAULT 0,
      contact_details   TEXT,
      amount_paid       REAL NOT NULL DEFAULT 0,
      supplier_wallet   REAL NOT NULL DEFAULT 0,
      $_syncCols
    )
  ''';

  static const _createCustomers = '''
    CREATE TABLE IF NOT EXISTS customers (
      id                    TEXT PRIMARY KEY,
      name                  TEXT NOT NULL,
      address_text          TEXT NOT NULL,
      google_maps_location  TEXT NOT NULL,
      phone                 TEXT,
      customer_wallet       REAL NOT NULL DEFAULT 0,
      wallet_limit          REAL NOT NULL DEFAULT 0,
      customer_group        TEXT NOT NULL DEFAULT 'retailer',
      is_walk_in            INTEGER NOT NULL DEFAULT 0,
      created_at            TEXT NOT NULL,
      $_syncCols
    )
  ''';

  static const _createCustomerPayments = '''
    CREATE TABLE IF NOT EXISTS customer_payments (
      id           TEXT PRIMARY KEY,
      customer_id  TEXT NOT NULL,
      amount       REAL NOT NULL,
      timestamp    TEXT NOT NULL,
      note         TEXT,
      $_syncCols
    )
  ''';

  static const _createCustomerCrateBalances = '''
    CREATE TABLE IF NOT EXISTS customer_crate_balances (
      customer_id   TEXT NOT NULL,
      crate_group   TEXT NOT NULL,
      qty           INTEGER NOT NULL DEFAULT 0,
      updated_at    TEXT NOT NULL,
      PRIMARY KEY (customer_id, crate_group)
    )
  ''';

  static const _createOrders = '''
    CREATE TABLE IF NOT EXISTS orders (
      id               TEXT PRIMARY KEY,
      customer_id      TEXT,
      customer_name    TEXT NOT NULL,
      customer_address TEXT NOT NULL DEFAULT '',
      customer_phone   TEXT NOT NULL DEFAULT '',
      subtotal         REAL NOT NULL DEFAULT 0,
      crate_deposit    REAL NOT NULL DEFAULT 0,
      total_amount     REAL NOT NULL,
      amount_paid      REAL NOT NULL,
      customer_wallet  REAL NOT NULL DEFAULT 0,
      payment_method   TEXT NOT NULL,
      created_at       TEXT NOT NULL,
      completed_at     TEXT,
      status           TEXT NOT NULL DEFAULT 'pending',
      rider_name       TEXT NOT NULL DEFAULT 'Pick-up Order',
      $_syncCols
    )
  ''';

  static const _createOrderItems = '''
    CREATE TABLE IF NOT EXISTS order_items (
      id                 TEXT PRIMARY KEY,
      order_id           TEXT NOT NULL,
      product_name       TEXT NOT NULL,
      subtitle           TEXT,
      price              REAL NOT NULL,
      qty                REAL NOT NULL,
      category           TEXT,
      crate_group_name   TEXT,
      needs_empty_crate  INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _createOrderReprints = '''
    CREATE TABLE IF NOT EXISTS order_reprints (
      id           TEXT PRIMARY KEY,
      order_id     TEXT NOT NULL,
      reprinted_at TEXT NOT NULL
    )
  ''';

  static const _createExpenses = '''
    CREATE TABLE IF NOT EXISTS expenses (
      id              TEXT PRIMARY KEY,
      category        TEXT NOT NULL,
      amount          REAL NOT NULL,
      payment_method  TEXT NOT NULL,
      description     TEXT,
      date            TEXT NOT NULL,
      created_at      TEXT NOT NULL,
      recorded_by     TEXT NOT NULL,
      reference       TEXT,
      receipt_path    TEXT,
      $_syncCols
    )
  ''';

  static const _createDeliveries = '''
    CREATE TABLE IF NOT EXISTS deliveries (
      id             TEXT PRIMARY KEY,
      supplier_name  TEXT NOT NULL,
      delivered_at   TEXT NOT NULL,
      total_value    REAL NOT NULL DEFAULT 0,
      status         TEXT NOT NULL DEFAULT 'pending',
      $_syncCols
    )
  ''';

  static const _createDeliveryItems = '''
    CREATE TABLE IF NOT EXISTS delivery_items (
      id                TEXT PRIMARY KEY,
      delivery_id       TEXT NOT NULL,
      product_id        TEXT NOT NULL DEFAULT '',
      product_name      TEXT NOT NULL,
      supplier_name     TEXT NOT NULL,
      crate_group_label TEXT,
      unit_price        REAL NOT NULL,
      quantity          REAL NOT NULL
    )
  ''';

  static const _createDeliveryReceipts = '''
    CREATE TABLE IF NOT EXISTS delivery_receipts (
      id                  TEXT PRIMARY KEY,
      order_id            TEXT NOT NULL,
      reference_number    TEXT NOT NULL,
      rider_name          TEXT NOT NULL,
      outstanding_amount  REAL NOT NULL DEFAULT 0,
      paid_amount         REAL NOT NULL DEFAULT 0,
      created_at          TEXT NOT NULL,
      $_syncCols
    )
  ''';

  static const _createSupplierPayments = '''
    CREATE TABLE IF NOT EXISTS supplier_payments (
      id                TEXT PRIMARY KEY,
      supplier_id       TEXT,
      supplier_name     TEXT NOT NULL,
      amount            REAL NOT NULL,
      payment_method    TEXT NOT NULL,
      reference_number  TEXT,
      notes             TEXT,
      delivery_id       TEXT,
      date              TEXT NOT NULL,
      created_at        TEXT NOT NULL,
      $_syncCols
    )
  ''';

  static const _createInventoryLogs = '''
    CREATE TABLE IF NOT EXISTS inventory_logs (
      id              TEXT PRIMARY KEY,
      timestamp       TEXT NOT NULL,
      user            TEXT NOT NULL,
      item_id         TEXT NOT NULL,
      item_name       TEXT NOT NULL,
      action          TEXT NOT NULL,
      previous_value  REAL NOT NULL,
      new_value       REAL NOT NULL,
      note            TEXT,
      $_syncCols
    )
  ''';

  static const _createActivityLogs = '''
    CREATE TABLE IF NOT EXISTS activity_logs (
      id                    TEXT PRIMARY KEY,
      action                TEXT NOT NULL,
      description           TEXT NOT NULL,
      timestamp             TEXT NOT NULL,
      related_entity_id     TEXT,
      related_entity_type   TEXT,
      $_syncCols
    )
  ''';

  static const _createNotifications = '''
    CREATE TABLE IF NOT EXISTS notifications (
      id               TEXT PRIMARY KEY,
      type             TEXT NOT NULL,
      message          TEXT NOT NULL,
      timestamp        TEXT NOT NULL,
      is_read          INTEGER NOT NULL DEFAULT 0,
      linked_record_id TEXT,
      $_syncCols
    )
  ''';

  static const _createStaff = '''
    CREATE TABLE IF NOT EXISTS staff (
      id    TEXT PRIMARY KEY,
      name  TEXT NOT NULL,
      role  TEXT NOT NULL,
      $_syncCols
    )
  ''';

  static const _createSyncMeta = '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      table_name     TEXT PRIMARY KEY,
      last_synced_at TEXT NOT NULL
    )
  ''';
}

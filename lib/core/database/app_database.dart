import 'dart:io';


import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:reebaplus_pos/core/database/daos.dart';
export 'daos.dart';

part 'app_database.g.dart';

// 1. Crate Groups
@DataClassName('CrateGroupData')
class CrateGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get size => integer()(); // 12=big, 20=medium, 24=small
  IntColumn get emptyCrateStock => integer().withDefault(const Constant(0))();
  IntColumn get depositAmountKobo => integer().withDefault(const Constant(0))();
}

// 1b. Manufacturers — first-class entities that own crate pools
@DataClassName('ManufacturerData')
class Manufacturers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get emptyCrateStock => integer().withDefault(const Constant(0))();
  IntColumn get depositAmountKobo => integer().withDefault(const Constant(0))();
}

// 2. Warehouses
@DataClassName('WarehouseData')
class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
}

// 3. Users
@DataClassName('UserData')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable().unique()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get pin => text()(); // 4-digit PIN
  TextColumn get role => text()(); // admin, staff, CEO
  IntColumn get roleTier => integer().withDefault(const Constant(1))(); // 1=Staff, 4=Manager, 5=CEO
  TextColumn get avatarColor => text().withDefault(const Constant('#3B82F6'))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get lastNotificationSentAt => dateTime().nullable()();
}

// 4. Categories
@DataClassName('CategoryData')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
}

// 5. Products
// Indexes speed up filtering by category and searching by name.
// Think of an index like a book's index — it lets the database jump
// directly to the right rows instead of reading every single row.
@TableIndex(name: 'idx_products_category_id', columns: {#categoryId})
@TableIndex(name: 'idx_products_name', columns: {#name})
@DataClassName('ProductData')
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get crateGroupId => integer().nullable().references(CrateGroups, #id)();
  TextColumn get crateSize => text().nullable()(); // 'big' | 'medium' | 'small'
  TextColumn get name => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get sku => text().nullable()();
  IntColumn get retailPriceKobo => integer().withDefault(const Constant(0))();
  IntColumn get bulkBreakerPriceKobo => integer().nullable()();
  IntColumn get distributorPriceKobo => integer().nullable()();
  IntColumn get sellingPriceKobo => integer().withDefault(const Constant(0))();
  IntColumn get buyingPriceKobo => integer().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('Bottle'))();
  IntColumn get iconCodePoint => integer().nullable()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get manufacturerId => integer().nullable().references(Manufacturers, #id)();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get manufacturer => text().nullable()(); // kept for display; mirrors manufacturerId.name
  RealColumn get avgDailySales => real().withDefault(const Constant(0.0))();
  IntColumn get leadTimeDays => integer().withDefault(const Constant(0))();
  IntColumn get safetyStockQty => integer().withDefault(const Constant(0))();
  IntColumn get monthlyTargetUnits => integer().withDefault(const Constant(0))();
  IntColumn get emptyCrateValueKobo => integer().withDefault(const Constant(0))();
}

// 6. Inventory
@DataClassName('InventoryData')
class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
}

// 7. Customers
@DataClassName('CustomerData')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get googleMapsLocation => text().nullable()();
  TextColumn get customerGroup => text().withDefault(const Constant('retailer'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get walletBalanceKobo => integer().withDefault(const Constant(0))();
  IntColumn get walletLimitKobo => integer().withDefault(const Constant(0))();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
}

// 8. Suppliers
@DataClassName('SupplierData')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get crateGroupName => text().nullable()();
}

// 9. Orders
@DataClassName('OrderData')
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text()(); 
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get totalAmountKobo => integer()();
  IntColumn get discountKobo => integer().withDefault(const Constant(0))();
  IntColumn get netAmountKobo => integer()();
  IntColumn get amountPaidKobo => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get status => text()(); // pending, completed, cancelled, refunded
  TextColumn get riderName => text().withDefault(const Constant('Pick-up Order'))();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get staffId => integer().nullable().references(Users, #id)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
  IntColumn get crateDepositPaidKobo => integer().withDefault(const Constant(0))();
}

// 10. Order Items
@DataClassName('OrderItemData')
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceKobo => integer()();
  IntColumn get buyingPriceKobo => integer().withDefault(const Constant(0))();
  IntColumn get totalKobo => integer()();
  TextColumn get priceSnapshot => text().nullable()();
}

// 11. Purchases
@DataClassName('DeliveryData')
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get totalAmountKobo => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()();
}

// 12. Purchase Items
@DataClassName('PurchaseItemData')
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceKobo => integer()();
  IntColumn get totalKobo => integer()();
}

// 13. Expenses
@DataClassName('ExpenseData')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(ExpenseCategories, #id)();
  TextColumn get category => text().withDefault(const Constant('Others'))();
  IntColumn get amountKobo => integer()();
  TextColumn get description => text()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get warehouseId => integer().nullable().references(Warehouses, #id)();
}

// 14. Expense Categories
@DataClassName('ExpenseCategoryData')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

// 15. Crates (Inventory)
@DataClassName('CrateData')
class Crates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get totalCrates => integer()();
  IntColumn get emptyReturned => integer().withDefault(const Constant(0))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 16. Customer Crate Balances
class CustomerCrateBalances extends Table {
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get crateGroupId => integer().references(CrateGroups, #id)();
  IntColumn get balance => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {customerId, crateGroupId};
}

// 17. Sync Queue
@DataClassName('SyncQueueData')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, done, failed
  TextColumn get errorMessage => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}

// 18. App Settings
@DataClassName('AppSettingData')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 19. Delivery Receipts
@DataClassName('DeliveryReceiptData')
class DeliveryReceipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  IntColumn get driverId => integer().references(Drivers, #id)();
  TextColumn get status => text()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
}

// 20. Drivers
@DataClassName('DriverData')
class Drivers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get licenseNumber => text().nullable()();
  TextColumn get phone => text().nullable()();
}

// 21. Price Lists
@DataClassName('PriceListData')
class PriceLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get priceKobo => integer()();
  DateTimeColumn get effectiveFrom => dateTime().withDefault(currentDateAndTime)();
}

// 22. Payment Transactions
@DataClassName('PaymentTransactionData')
class PaymentTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get referenceId => integer()();
  TextColumn get type => text()(); // sale, purchase, expense
  IntColumn get amountKobo => integer()();
  TextColumn get method => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 23. Stock Transfers
@DataClassName('StockTransferData')
class StockTransfers extends Table {
  IntColumn get transferId => integer().autoIncrement()();
  IntColumn get fromLocationId => integer().references(Warehouses, #id)();
  IntColumn get toLocationId => integer().references(Warehouses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_transit, received, cancelled
  IntColumn get initiatedBy => integer().references(Users, #id)();
  IntColumn get receivedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get initiatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get receivedAt => dateTime().nullable()();
}

// 24. Stock Adjustments
@DataClassName('StockAdjustmentData')
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantityDiff => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 25. Activity Logs
@DataClassName('ActivityLogData')
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get description => text()();
  TextColumn get relatedEntityId => text().nullable()();
  TextColumn get relatedEntityType => text().nullable()();
  TextColumn get warehouseId => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 26. Notifications
@DataClassName('NotificationData')
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get message => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get linkedRecordId => text().nullable()();
}

// 27. Settings
@DataClassName('SettingData')
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}

// 28. Stock Transactions Ledger — source of truth for all stock movements
@DataClassName('StockTransactionData')
class StockTransactions extends Table {
  // UUID v4 text PK — caller must set before insert
  TextColumn get transactionId => text()();

  IntColumn get productId    => integer().references(Products, #id)();
  IntColumn get locationId   => integer().references(Warehouses, #id)();

  // Negative = outflow (sale, damage, transfer_out)
  // Positive = inflow  (purchase_received, return, transfer_in, adjustment)
  IntColumn get quantityDelta => integer()();

  // movement_type: sale | return | damage | transfer_out | transfer_in | purchase_received | adjustment
  TextColumn get movementType => text()();
  
  TextColumn get referenceId  => text().nullable()(); // orderId, transferId, etc.
  IntColumn get performedBy   => integer().references(Users, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt  => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {transactionId};
}

// 29. Sessions
@DataClassName('SessionData')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get token => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 30. Customer Wallet Transactions
@DataClassName('CustomerWalletTransactionData')
class CustomerWalletTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get amountDeltaKobo => integer()();
  TextColumn get type => text()(); // credit, debit, refund
  IntColumn get staffId => integer().references(Users, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 31. Customer Wallets
@DataClassName('CustomerWalletData')
class CustomerWallets extends Table {
  TextColumn get walletId => text()(); // UUID v4
  IntColumn get customerId => integer().unique().references(Customers, #id)();
  TextColumn get currency => text().withDefault(const Constant('NGN'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {walletId};
}

// 32. Wallet Transactions
@DataClassName('WalletTransactionData')
class WalletTransactions extends Table {
  TextColumn get txnId => text()(); // UUID v4
  TextColumn get walletId => text().references(CustomerWallets, #walletId)();
  TextColumn get type => text()(); // credit, debit
  IntColumn get amountKobo => integer()(); // always positive
  TextColumn get referenceType => text()(); // topup_cash, topup_transfer, order_payment, refund, reward, fee
  TextColumn get referenceId => text().nullable()();
  IntColumn get performedBy => integer().references(Users, #id)();
  BoolColumn get customerVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {txnId};
}

// 33. Saved Carts
@DataClassName('SavedCartData')
class SavedCarts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get cartData => text()(); // JSON-encoded cart items
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 34. Pending Crate Returns — short returns awaiting manager approval
@DataClassName('PendingCrateReturnData')
class PendingCrateReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get staffId => integer().references(Users, #id)();
  TextColumn get returnDataJson => text()(); // JSON: [{crateGroupId,crateGroupName,expectedQty,returnedQty}]
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending/approved/rejected
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    CrateGroups,
    Manufacturers,
    Warehouses,
    Users,
    Categories,
    Products,
    Inventory,
    Customers,
    Suppliers,
    Orders,
    OrderItems,
    Purchases,
    PurchaseItems,
    Expenses,
    ExpenseCategories,
    Crates,
    CustomerCrateBalances,
    SyncQueue,
    AppSettings,
    DeliveryReceipts,
    Drivers,
    PriceLists,
    PaymentTransactions,
    StockTransfers,
    StockAdjustments,
    ActivityLogs,
    Notifications,
    Settings,
    Sessions,
    CustomerWalletTransactions,
    StockTransactions,
    CustomerWallets,
    WalletTransactions,
    SavedCarts,
    PendingCrateReturns,
  ],
  daos: [
    CatalogDao,
    InventoryDao,
    OrdersDao,
    CustomersDao,
    DeliveriesDao,
    ExpensesDao,
    SyncDao,
    ActivityLogDao,
    NotificationsDao,
    WarehousesDao,
    StockLedgerDao,
    StockTransferDao,
    PendingCrateReturnsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 29;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          debugPrint('[AppDatabase] onCreate: Creating database tables...');
          await m.createAll();
          debugPrint('[AppDatabase] onCreate: Seeding system defaults...');
          await _seedData();           // crate groups + categories
          debugPrint('[AppDatabase] onCreate: Seeding business data...');
          await _seedBusinessData();   // warehouses, staff, products, inventory
          debugPrint('[AppDatabase] onCreate: Database setup complete.');
        },
        onUpgrade: (m, from, to) async {
          debugPrint('[AppDatabase] onUpgrade: Upgrading from version $from to $to...');
          try {
            await customStatement('PRAGMA foreign_keys = OFF');

            if (from < 20) {
              await m.createTable(savedCarts);
            }

            if (from < 22) {
              // Migration to 22: Added nullable createdAt and lastNotificationSentAt via raw SQL (User's manual edit)
              // We try to add them again via Migrator in case v22 failed to align schema metadata
              try { await m.addColumn(users, users.createdAt); } catch (_) {}
              try { await m.addColumn(users, users.lastNotificationSentAt); } catch (_) {}
            }

            if (from < 23) {
              // Version 23: Rescue migration to ensure column consistency.
              try { await m.addColumn(users, users.createdAt); } catch (_) {}
              try { await m.addColumn(users, users.lastNotificationSentAt); } catch (_) {}

              final existingUsers = await select(users).get();
              if (existingUsers.isEmpty) {
                await _seedDefaultStaff();
              }
            }

            if (from < 24) {
              // Version 24: Add warehouseId to Customers for per-warehouse customer isolation.
              try { await m.addColumn(customers, customers.warehouseId); } catch (_) {}
            }

            if (from < 25) {
              // Version 25: Add warehouseId to Orders and Expenses for per-warehouse filtering.
              try { await m.addColumn(orders, orders.warehouseId); } catch (_) {}
              try { await m.addColumn(expenses, expenses.warehouseId); } catch (_) {}
            }

            if (from < 26) {
              // Version 26: Add crateDepositPaidKobo to Orders for crate deposit tracking.
              try { await m.addColumn(orders, orders.crateDepositPaidKobo); } catch (_) {}
            }

            if (from < 27) {
              // Version 27: Snapshot buying price on OrderItems so profit history is unaffected by future price changes.
              try { await m.addColumn(orderItems, orderItems.buyingPriceKobo); } catch (_) {}
            }

            if (from < 28) {
              // Version 28: Add PendingCrateReturns table for staff short-return approval workflow.
              await m.createTable(pendingCrateReturns);
            }

            if (from < 29) {
              // Version 29: Migrate all 4-digit PINs to 6 digits by appending '00'.
              // e.g. '0000' → '000000', '1111' → '111100'. Existing users enter old PIN + '00'.
              try {
                await customStatement(
                  "UPDATE users SET pin = pin || '00' WHERE LENGTH(pin) = 4",
                );
              } catch (e) {
                debugPrint('[AppDatabase] v29 PIN migration error: $e');
              }
            }

            // Fallback: Create any other new tables that do not yet exist
            for (final table in allTables) {
              await m.createTable(table).catchError((_) => Future.value());
            }
            await customStatement('PRAGMA foreign_keys = ON');
          } catch (e) {
            debugPrint('[AppDatabase] MIGRATION ERROR: $e');
          }
        },
      );

  Future<void> _seedData() async {
    await batch((b) {
      // Crate groups — system defaults used for deposit calculations
      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Big Crate 12'), size: Value(12), depositAmountKobo: Value(150000)));
      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Medium Crate 20'), size: Value(20), depositAmountKobo: Value(150000)));
      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Small Crate 24'), size: Value(24), depositAmountKobo: Value(120000)));

      // Product categories
      b.insert(categories, const CategoriesCompanion(name: Value('Glass Crates')));
      b.insert(categories, const CategoriesCompanion(name: Value('Cans & PET')));
      b.insert(categories, const CategoriesCompanion(name: Value('Kegs')));
      b.insert(categories, const CategoriesCompanion(name: Value('Other')));
    });
  }

  /// Seeds real business data — branches, staff, products, and inventory.
  /// Called once from onCreate (fresh install only). Never call on existing DBs.
  Future<void> _seedBusinessData() => transaction(() async {
    // ── 0. Supplier ─────────────────────────────────────────────────────────
    final coldcrateId = await into(suppliers).insert(const SuppliersCompanion(
      name: Value('Coldcrate Ltd'),
      phone: Value('08000000000'),
    ));

    // ── 1. Manufacturers ────────────────────────────────────────────────────
    final nbId = await into(manufacturers).insert(const ManufacturersCompanion(
      name: Value('Nigerian Breweries'),
      depositAmountKobo: Value(150000), // ₦1,500 per bottle
      emptyCrateStock: Value(30),
    ));
    final gnId = await into(manufacturers).insert(const ManufacturersCompanion(
      name: Value('Guinness Nigeria'),
      depositAmountKobo: Value(150000), // ₦1,500 per bottle
      emptyCrateStock: Value(20),
    ));

    // ── 2. Warehouses ───────────────────────────────────────────────────────
    final pankshinId = await into(warehouses).insert(const WarehousesCompanion(
      name: Value('Pankshin Branch'),
    ));
    final keffiId = await into(warehouses).insert(const WarehousesCompanion(
      name: Value('Keffi Branch'),
    ));
    final tafawaId = await into(warehouses).insert(const WarehousesCompanion(
      name: Value('Tafawa Balewa Branch'),
    ));

    // ── 3. Staff (all inserted in one batch for speed) ──────────────────────
    await batch((b) {
      // Pankshin Branch
      b.insert(users, UsersCompanion(name: const Value('Okwor Camillus'), role: const Value('CEO'), roleTier: const Value(5), pin: const Value('000000'), warehouseId: Value(pankshinId), avatarColor: const Value('#8B5CF6')));
      b.insert(users, UsersCompanion(name: const Value('Okwor Felister'), role: const Value('manager'), roleTier: const Value(4), pin: const Value('111100'), warehouseId: Value(pankshinId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Okwor Solomon'), role: const Value('stock_keeper'), roleTier: const Value(3), pin: const Value('222200'), warehouseId: Value(pankshinId), avatarColor: const Value('#F59E0B')));
      b.insert(users, UsersCompanion(name: const Value('Okwor Malachi'), role: const Value('stock_keeper'), roleTier: const Value(3), pin: const Value('333300'), warehouseId: Value(pankshinId), avatarColor: const Value('#F59E0B')));
      b.insert(users, UsersCompanion(name: const Value('Boniface'), role: const Value('rider'), roleTier: const Value(1), pin: const Value('444400'), warehouseId: Value(pankshinId), avatarColor: const Value('#EF4444')));
      // Keffi Branch
      b.insert(users, UsersCompanion(name: const Value('Okwor Chimezie'), role: const Value('manager'), roleTier: const Value(4), pin: const Value('555500'), warehouseId: Value(keffiId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Eze Ebuka'), role: const Value('stock_keeper'), roleTier: const Value(3), pin: const Value('666600'), warehouseId: Value(keffiId), avatarColor: const Value('#F59E0B')));
      // Tafawa Balewa Branch (Dashe is manager — only person at this branch)
      b.insert(users, UsersCompanion(name: const Value('Dashe Gwimyol'), role: const Value('manager'), roleTier: const Value(4), pin: const Value('777700'), warehouseId: Value(tafawaId), avatarColor: const Value('#3B82F6')));
    });

    // ── 4. Resolve system category + crate group IDs ────────────────────────
    final cats = await select(categories).get();
    final glassCatId = cats.firstWhere((c) => c.name == 'Glass Crates').id;
    final cansCatId  = cats.firstWhere((c) => c.name == 'Cans & PET').id;

    final crateGrps  = await select(crateGroups).get();
    final bigCrateId = crateGrps.firstWhere((c) => c.size == 12).id;

    // ── 5. Products ─────────────────────────────────────────────────────────
    // sellingPriceKobo = retailPriceKobo so cart prices show immediately.
    // buyingPriceKobo  = retailPriceKobo to mirror the add-product form default.
    // colorHex is set so product cards show a colour accent (matches form behaviour).
    // 3 glass products
    final starId = await into(products).insert(ProductsCompanion(
      name: const Value('Star Lager Beer'),
      categoryId: Value(glassCatId),
      manufacturerId: Value(nbId), manufacturer: const Value('Nigerian Breweries'),
      supplierId: Value(coldcrateId),
      crateGroupId: Value(bigCrateId), crateSize: const Value('big'),
      retailPriceKobo: const Value(1160000), sellingPriceKobo: const Value(1160000),
      buyingPriceKobo: const Value(1080000), unit: const Value('Bottle'),
      colorHex: const Value('#F59E0B'),
    ));
    final heinId = await into(products).insert(ProductsCompanion(
      name: const Value('Heineken Beer'),
      categoryId: Value(glassCatId),
      manufacturerId: Value(nbId), manufacturer: const Value('Nigerian Breweries'),
      supplierId: Value(coldcrateId),
      crateGroupId: Value(bigCrateId), crateSize: const Value('big'),
      retailPriceKobo: const Value(1350000), sellingPriceKobo: const Value(1350000),
      buyingPriceKobo: const Value(1200000), unit: const Value('Bottle'),
      colorHex: const Value('#10B981'),
    ));
    final guinnId = await into(products).insert(ProductsCompanion(
      name: const Value('Guinness Stout'),
      categoryId: Value(glassCatId),
      manufacturerId: Value(gnId), manufacturer: const Value('Guinness Nigeria'),
      supplierId: Value(coldcrateId),
      crateGroupId: Value(bigCrateId), crateSize: const Value('big'),
      retailPriceKobo: const Value(1750000), sellingPriceKobo: const Value(1750000),
      buyingPriceKobo: const Value(1623000), unit: const Value('Bottle'),
      colorHex: const Value('#6B7280'),
    ));
    // 2 non-glass products
    final maltaId = await into(products).insert(ProductsCompanion(
      name: const Value('Malta Guinness'),
      categoryId: Value(cansCatId),
      manufacturerId: Value(gnId), manufacturer: const Value('Guinness Nigeria'),
      supplierId: Value(coldcrateId),
      retailPriceKobo: const Value(1435000), sellingPriceKobo: const Value(1435000),
      buyingPriceKobo: const Value(1350000), unit: const Value('Can'),
      colorHex: const Value('#92400E'),
    ));
    final himaltId = await into(products).insert(ProductsCompanion(
      name: const Value('Hi-Malt'),
      categoryId: Value(cansCatId),
      manufacturerId: Value(nbId), manufacturer: const Value('Nigerian Breweries'),
      supplierId: Value(coldcrateId),
      retailPriceKobo: const Value(1130000), sellingPriceKobo: const Value(1130000),
      buyingPriceKobo: const Value(1030000), unit: const Value('Can'),
      colorHex: const Value('#3B82F6'),
    ));

    // ── 6. Inventory per warehouse ──────────────────────────────────────────
    // quantities[product][warehouse]: [Pankshin, Keffi, Tafawa Balewa]
    final productIds  = [starId, heinId, guinnId, maltaId, himaltId];
    final warehouseIds = [pankshinId, keffiId, tafawaId];
    final quantities  = [
      [240, 120, 60],  // Star Lager Beer
      [120,  60, 60],  // Heineken Beer
      [120,  60, 60],  // Guinness Stout
      [ 48,  24, 24],  // Malta Guinness
      [ 48,  24, 24],  // Hi-Malt
    ];

    await batch((b) {
      for (var p = 0; p < productIds.length; p++) {
        for (var w = 0; w < warehouseIds.length; w++) {
          b.insert(inventory, InventoryCompanion(
            productId:   Value(productIds[p]),
            warehouseId: Value(warehouseIds[w]),
            quantity:    Value(quantities[p][w]),
          ));
        }
      }
    });

    // ── 7. Additional staff — Riders, Cashiers, Cleaners ───────────────────
    await batch((b) {
      // Riders (PIN 8888–0011)
      b.insert(users, UsersCompanion(name: const Value('Usman Garba'), role: const Value('rider'), roleTier: const Value(1), pin: const Value('888800'), warehouseId: Value(pankshinId), avatarColor: const Value('#F97316')));
      b.insert(users, UsersCompanion(name: const Value('Daniel Markus'), role: const Value('rider'), roleTier: const Value(1), pin: const Value('999900'), warehouseId: Value(keffiId), avatarColor: const Value('#F97316')));
      b.insert(users, UsersCompanion(name: const Value('John Pwajok'), role: const Value('rider'), roleTier: const Value(1), pin: const Value('001100'), warehouseId: Value(tafawaId), avatarColor: const Value('#F97316')));
      // Cashiers (PIN 223300–778800)
      b.insert(users, UsersCompanion(name: const Value('Amina Yusuf'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('223300'), warehouseId: Value(pankshinId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Grace Dung'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('334400'), warehouseId: Value(pankshinId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Joseph Danjuma'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('445500'), warehouseId: Value(pankshinId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Fatima Idris'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('556600'), warehouseId: Value(keffiId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Emmanuel Lot'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('667700'), warehouseId: Value(keffiId), avatarColor: const Value('#3B82F6')));
      b.insert(users, UsersCompanion(name: const Value('Mary Fom'), role: const Value('cashier'), roleTier: const Value(2), pin: const Value('778800'), warehouseId: Value(tafawaId), avatarColor: const Value('#3B82F6')));
      // Cleaners (PIN 889900–101000)
      b.insert(users, UsersCompanion(name: const Value('Haruna Bulus'), role: const Value('cleaner'), roleTier: const Value(1), pin: const Value('889900'), warehouseId: Value(pankshinId), avatarColor: const Value('#94A3B8')));
      b.insert(users, UsersCompanion(name: const Value('Rebecca Luka'), role: const Value('cleaner'), roleTier: const Value(1), pin: const Value('990000'), warehouseId: Value(keffiId), avatarColor: const Value('#94A3B8')));
      b.insert(users, UsersCompanion(name: const Value('Sunday Nden'), role: const Value('cleaner'), roleTier: const Value(1), pin: const Value('101000'), warehouseId: Value(tafawaId), avatarColor: const Value('#94A3B8')));
    });

    // ── 8. Customers (5 sample accounts + a wallet for each) ───────────────
    // Must be sequential (not batch) so we capture each customer's auto-ID
    // to create the matching CustomerWallet row. Without a wallet row,
    // addCustomer() behaviour is not replicated and wallet screens crash.
    final c1 = await into(customers).insert(CustomersCompanion(name: const Value('Adamu Musa'), phone: const Value('08031234567'), address: const Value('Pankshin Market'), customerGroup: const Value('retailer'), warehouseId: Value(pankshinId)));
    await into(customerWallets).insert(CustomerWalletsCompanion.insert(walletId: 'wlt-seed-$c1', customerId: c1));

    final c2 = await into(customers).insert(CustomersCompanion(name: const Value('Hadiza Bello'), phone: const Value('08056781234'), address: const Value('Pankshin Junction'), customerGroup: const Value('wholesaler'), warehouseId: Value(pankshinId)));
    await into(customerWallets).insert(CustomerWalletsCompanion.insert(walletId: 'wlt-seed-$c2', customerId: c2));

    final c3 = await into(customers).insert(CustomersCompanion(name: const Value('Ibrahim Suleiman'), phone: const Value('08098765432'), address: const Value('Keffi Road'), customerGroup: const Value('retailer'), warehouseId: Value(keffiId)));
    await into(customerWallets).insert(CustomerWalletsCompanion.insert(walletId: 'wlt-seed-$c3', customerId: c3));

    final c4 = await into(customers).insert(CustomersCompanion(name: const Value('Ngozi Okafor'), phone: const Value('07061234567'), address: const Value('Keffi Market'), customerGroup: const Value('wholesaler'), warehouseId: Value(keffiId)));
    await into(customerWallets).insert(CustomerWalletsCompanion.insert(walletId: 'wlt-seed-$c4', customerId: c4));

    final c5 = await into(customers).insert(CustomersCompanion(name: const Value('Yusuf Danladi'), phone: const Value('08123456789'), address: const Value('Tafawa Balewa Central'), customerGroup: const Value('retailer'), warehouseId: Value(tafawaId)));
    await into(customerWallets).insert(CustomerWalletsCompanion.insert(walletId: 'wlt-seed-$c5', customerId: c5));
  });

  /// Seeds the 5 default staff accounts.
  /// Safe to call any time — only used when the Users table is empty.
  Future<void> _seedDefaultStaff() async {
    await batch((b) {
      b.insert(users, const UsersCompanion(name: Value('CEO'), role: Value('CEO'), roleTier: Value(5), pin: Value('000000'), avatarColor: Value('#8B5CF6')));
      b.insert(users, const UsersCompanion(name: Value('Manager'), role: Value('manager'), roleTier: Value(4), pin: Value('111100'), avatarColor: Value('#3B82F6')));
      b.insert(users, const UsersCompanion(name: Value('Cashier'), role: Value('cashier'), roleTier: Value(2), pin: Value('222200'), avatarColor: Value('#10B981')));
      b.insert(users, const UsersCompanion(name: Value('Stock Keeper'), role: Value('stock_keeper'), roleTier: Value(3), pin: Value('333300'), avatarColor: Value('#F59E0B')));
      b.insert(users, const UsersCompanion(name: Value('Rider'), role: Value('rider'), roleTier: Value(1), pin: Value('444400'), avatarColor: Value('#EF4444')));
    });
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables) {
        await delete(table).go();
      }
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

  Future<void> resetDatabase() async {
    await clearAllData();
    await _seedData();
  }
}

final database = AppDatabase();

/// Set to true by main.dart after the DB warmup query succeeds.
/// LoginScreen reads this to skip its own wait if the DB is already ready.
bool dbReady = false;

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'reebaplus_pos.sqlite'));
    return NativeDatabase.createInBackground(file, setup: (db) {
      // Enable WAL mode for faster concurrent reads/writes.
      db.execute('PRAGMA journal_mode = WAL');
      // NORMAL is safe for app data and skips expensive per-write OS syncs.
      db.execute('PRAGMA synchronous = NORMAL');
      // 8 MB in-memory page cache to reduce disk I/O during table creation.
      db.execute('PRAGMA cache_size = -8000');
      // Keep temp tables in RAM instead of on disk.
      db.execute('PRAGMA temp_store = MEMORY');
    });
  });
}

import 'dart:io';


import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'daos.dart';
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
    StockTransferDao
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          debugPrint('[AppDatabase] onCreate: Creating database tables...');
          await m.createAll().timeout(const Duration(seconds: 15), onTimeout: () {
            throw Exception('Database creation timed out.');
          });
          debugPrint('[AppDatabase] onCreate: Seeding initial data...');
          await _seedData();
          debugPrint('[AppDatabase] onCreate: Database setup complete.');
        },
        onUpgrade: (m, from, to) async {
          debugPrint('[AppDatabase] onUpgrade: Upgrading from version $from to $to...');
          try {
            await customStatement('PRAGMA foreign_keys = OFF');

            if (from < 20) {
              await m.createTable(savedCarts);
            }

            // v21 — no DDL changes; default staff users are seeded on fresh installs only.
            // Existing installs keep their current Users rows untouched.

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
      // Default warehouse — users can add more from the Warehouse screen
      b.insert(warehouses, const WarehousesCompanion(name: Value('Main Store')));

      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Big Crate 12'), size: Value(12), depositAmountKobo: Value(150000)));
      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Medium Crate 20'), size: Value(20), depositAmountKobo: Value(150000)));
      b.insert(crateGroups, const CrateGroupsCompanion(name: Value('Small Crate 24'), size: Value(24), depositAmountKobo: Value(120000)));

      b.insert(categories, const CategoriesCompanion(name: Value('Glass Crates')));
      b.insert(categories, const CategoriesCompanion(name: Value('Cans & PET')));
      b.insert(categories, const CategoriesCompanion(name: Value('Kegs')));
      b.insert(categories, const CategoriesCompanion(name: Value('Other')));

      // ── Default Staff ────────────────────────────────────────────────────────
      // These are placeholder accounts. Real login details will be set later.
      // PINs follow a simple pattern so staff can log in immediately on a fresh device.
      b.insert(
        users,
        const UsersCompanion(
          name: Value('CEO'),
          role: Value('CEO'),
          roleTier: Value(5),
          pin: Value('0000'),
          avatarColor: Value('#8B5CF6'), // purple
        ),
      );
      b.insert(
        users,
        const UsersCompanion(
          name: Value('Manager'),
          role: Value('manager'),
          roleTier: Value(4),
          pin: Value('1111'),
          avatarColor: Value('#3B82F6'), // blue
        ),
      );
      b.insert(
        users,
        const UsersCompanion(
          name: Value('Cashier'),
          role: Value('cashier'),
          roleTier: Value(1),
          pin: Value('2222'),
          avatarColor: Value('#10B981'), // green
        ),
      );
      b.insert(
        users,
        const UsersCompanion(
          name: Value('Stock Keeper'),
          role: Value('stock_keeper'),
          roleTier: Value(1),
          pin: Value('3333'),
          avatarColor: Value('#F59E0B'), // amber
        ),
      );
      b.insert(
        users,
        const UsersCompanion(
          name: Value('Rider'),
          role: Value('rider'),
          roleTier: Value(1),
          pin: Value('4444'),
          avatarColor: Value('#EF4444'), // red
        ),
      );
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ribaplus_pos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

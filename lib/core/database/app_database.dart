import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'daos.dart';

part 'app_database.g.dart';

// 1. Crate Groups
@DataClassName('CrateGroupData')
class CrateGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get size => integer()(); // e.g., 24, 12
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
  TextColumn get pin => text()(); // 4-digit PIN
  TextColumn get role => text()(); // admin, staff, etc.
  IntColumn get roleTier => integer().withDefault(const Constant(1))(); // 1=Staff, 4=Manager, 5=CEO
  TextColumn get avatarColor => text().withDefault(const Constant('#3B82F6'))(); // HEX color
}

// 4. Categories
@DataClassName('CategoryData')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
}

// 5. Products
@DataClassName('ProductData')
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get sku => text().nullable()();
  IntColumn get retailPriceKobo => integer().withDefault(const Constant(0))();
  IntColumn get bulkBreakerPriceKobo => integer().nullable()();
  IntColumn get distributorPriceKobo => integer().nullable()();
  IntColumn get sellingPriceKobo => integer().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('Bottle'))();
  IntColumn get iconCodePoint => integer().nullable()();
  TextColumn get colorHex => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
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
}

// 9. Orders
@DataClassName('OrderData')
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text()(); // e.g. ORD-20240314-001
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get totalAmountKobo => integer()();
  IntColumn get discountKobo => integer().withDefault(const Constant(0))();
  IntColumn get netAmountKobo => integer()();
  IntColumn get amountPaidKobo => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text()(); // cash, transfer, pos, wallet, multi
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get status => text()(); // pending, completed, cancelled, refunded
  TextColumn get riderName => text().withDefault(const Constant('Pick-up Order'))();
  TextColumn get cancellationReason => text().nullable()();
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
  TextColumn get priceSnapshot => text().nullable()(); // JSON detail
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
  IntColumn get categoryId => integer().references(ExpenseCategories, #id)();
  IntColumn get amountKobo => integer()();
  TextColumn get description => text()();
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
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromWarehouseId => integer().references(Warehouses, #id)();
  IntColumn get toWarehouseId => integer().references(Warehouses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
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

// 23. Notifications
@DataClassName('NotificationData')
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get message => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get linkedRecordId => text().nullable()();
}

// 24. Settings
@DataClassName('SettingData')
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}

// 25. Sessions
@DataClassName('SessionData')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get token => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 26. Customer Wallet Transactions
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

@DriftDatabase(
  tables: [
    CrateGroups,
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
  ],
  daos: [CatalogDao, InventoryDao, OrdersDao, CustomersDao, DeliveriesDao, ExpensesDao, SyncDao, ActivityLogDao, NotificationsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Initial seeding
          await batch((b) {
            b.insert(
              crateGroups,
              CrateGroupsCompanion.insert(name: 'Full Crate 24', size: 24),
            );
            b.insert(
              crateGroups,
              CrateGroupsCompanion.insert(name: 'Half Crate 12', size: 12),
            );
            b.insert(
              warehouses,
              WarehousesCompanion.insert(name: 'Main Warehouse', location: const Value('Default Location')),
            );
            b.insert(
              users,
              UsersCompanion.insert(name: 'CEO Admin', pin: '1234', role: 'ceo', roleTier: const Value(5), avatarColor: const Value('#FEF08A')),
            );
            b.insert(
              users,
              UsersCompanion.insert(name: 'Manager Mike', pin: '1111', role: 'manager', roleTier: const Value(4), avatarColor: const Value('#A855F7')),
            );
            b.insert(
              users,
              UsersCompanion.insert(name: 'John Cashier', pin: '0000', role: 'staff', roleTier: const Value(1), avatarColor: const Value('#3B82F6')),
            );
            b.insert(
              users,
              UsersCompanion.insert(name: 'Sarah Waitress', pin: '5678', role: 'staff', roleTier: const Value(1), avatarColor: const Value('#F472B6')),
            );

            // Seed Categories
            b.insert(categories, CategoriesCompanion.insert(name: 'Glass Crates', description: const Value('Traditional glass bottle crates')));
            b.insert(categories, CategoriesCompanion.insert(name: 'Cans & PET', description: const Value('Aluminum cans and plastic bottles')));

            // Seed Products
            b.insert(products, ProductsCompanion.insert(
              categoryId: const Value(1),
              name: 'Star Lager',
              subtitle: const Value('Crate'),
              unit: const Value('Crate'),
              retailPriceKobo: const Value(500000), // 5,000.00
              sellingPriceKobo: const Value(500000),
              iconCodePoint: const Value(0xf0fc), // beer-mug-empty
              colorHex: const Value('#F59E0B'),
            ));
            
            b.insert(products, ProductsCompanion.insert(
              categoryId: const Value(2),
              name: 'Heineken',
              subtitle: const Value('Can'),
              unit: const Value('Can'),
              retailPriceKobo: const Value(850000),
              sellingPriceKobo: const Value(850000),
              iconCodePoint: const Value(0xf72f), // wine-bottle
              colorHex: const Value('#10B981'),
            ));

            // Seed Inventory
            b.insert(inventory, InventoryCompanion.insert(productId: 1, warehouseId: 1, quantity: const Value(50)));
            b.insert(inventory, InventoryCompanion.insert(productId: 2, warehouseId: 1, quantity: const Value(100)));
          });
        },
      );
}

final database = AppDatabase();

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'onafia_pos.sqlite'));
    return NativeDatabase(file);
  });
}

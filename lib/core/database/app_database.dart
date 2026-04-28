import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:reebaplus_pos/core/database/daos.dart';
import 'package:reebaplus_pos/core/diagnostics/schema_audit.dart';
export 'daos.dart';

part 'app_database.g.dart';

// 1. Crate Groups
@DataClassName('CrateGroupData')
class CrateGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  IntColumn get size => integer()(); // 12=big, 20=medium, 24=small
  IntColumn get emptyCrateStock => integer().withDefault(const Constant(0))();
  IntColumn get depositAmountKobo => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 1b. Manufacturers — first-class entities that own crate pools
@DataClassName('ManufacturerData')
class Manufacturers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  IntColumn get emptyCrateStock => integer().withDefault(const Constant(0))();
  IntColumn get depositAmountKobo => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 1c. Businesses
@DataClassName('BusinessData')
class Businesses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
}

// 2. Warehouses
@DataClassName('WarehouseData')
class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 3. Users
@DataClassName('UserData')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable().unique()();
  TextColumn get passwordHash => text().nullable()();
  // Vestigial post-v35: holds the literal '__HASHED__' once the row is
  // migrated. Real PIN verification reads pinHash/pinSalt/pinIterations.
  // Sentinels '__SETUP_REQUIRED__' / 'TEMPPIN' / '' may still appear on rows
  // awaiting the first PIN setup.
  TextColumn get pin => text()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get pinSalt => text().nullable()();
  IntColumn get pinIterations => integer().nullable()();
  TextColumn get role => text()(); // admin, staff, CEO
  IntColumn get roleTier =>
      integer().withDefault(const Constant(1))(); // 1=Staff, 4=Manager, 5=CEO
  TextColumn get avatarColor => text().withDefault(const Constant('#3B82F6'))();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  IntColumn get businessId =>
      integer().nullable().references(Businesses, #id)();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get lastNotificationSentAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 4. Categories
@DataClassName('CategoryData')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
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
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get crateGroupId =>
      integer().nullable().references(CrateGroups, #id)();
  TextColumn get size => text().nullable()(); // 'big' | 'medium' | 'small'
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
  IntColumn get manufacturerId =>
      integer().nullable().references(Manufacturers, #id)();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get manufacturer =>
      text().nullable()(); // kept for display; mirrors manufacturerId.name
  RealColumn get avgDailySales => real().withDefault(const Constant(0.0))();
  IntColumn get leadTimeDays => integer().withDefault(const Constant(0))();
  IntColumn get safetyStockQty => integer().withDefault(const Constant(0))();
  IntColumn get monthlyTargetUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get emptyCrateValueKobo =>
      integer().withDefault(const Constant(0))();
  BoolColumn get trackEmpties => boolean().withDefault(const Constant(false))();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 6. Inventory
@DataClassName('InventoryData')
class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 7. Customers
@DataClassName('CustomerData')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get googleMapsLocation => text().nullable()();
  TextColumn get customerGroup =>
      text().withDefault(const Constant('retailer'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get walletBalanceKobo => integer().withDefault(const Constant(0))();
  IntColumn get walletLimitKobo => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 8. Suppliers
@DataClassName('SupplierData')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get crateGroupName => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 9. Orders
@DataClassName('OrderData')
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
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
  TextColumn get riderName =>
      text().withDefault(const Constant('Pick-up Order'))();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get staffId => integer().nullable().references(Users, #id)();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  IntColumn get crateDepositPaidKobo =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 10. Order Items
@DataClassName('OrderItemData')
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceKobo => integer()();
  IntColumn get buyingPriceKobo => integer().withDefault(const Constant(0))();
  IntColumn get totalKobo => integer()();
  TextColumn get priceSnapshot => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 11. Purchases
@DataClassName('DeliveryData')
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get totalAmountKobo => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 12. Purchase Items
@DataClassName('PurchaseItemData')
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceKobo => integer()();
  IntColumn get totalKobo => integer()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 13. Expenses
@DataClassName('ExpenseData')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(ExpenseCategories, #id)();
  TextColumn get category => text().withDefault(const Constant('Others'))();
  IntColumn get amountKobo => integer()();
  TextColumn get description => text()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 14. Expense Categories
@DataClassName('ExpenseCategoryData')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 15. Crates (Inventory)
@DataClassName('CrateData')
class Crates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get totalCrates => integer()();
  IntColumn get emptyReturned => integer().withDefault(const Constant(0))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 16. Customer Crate Balances
class CustomerCrateBalances extends Table {
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get crateGroupId => integer().references(CrateGroups, #id)();
  IntColumn get balance => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {customerId, crateGroupId};
}

// 17. Sync Queue
@DataClassName('SyncQueueData')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nullable at the SQL layer to match every other tenant column; the API
  // (SyncDao.enqueue) requires non-null on insert and the v36 migration
  // backfills or moves any pre-existing NULL row to SyncQueueOrphans.
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get actionType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, in_progress, done, failed
  TextColumn get errorMessage => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}

// 17b. Sync Queue Orphans — rows the v36 backfill could not attribute to any
// tenant. Kept for diagnostics; never re-enters the push pipeline.
@DataClassName('SyncQueueOrphanData')
class SyncQueueOrphans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get originalId => integer()();
  TextColumn get actionType => text()();
  TextColumn get payload => text()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get movedAt => dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  IntColumn get driverId => integer().references(Drivers, #id)();
  TextColumn get status => text()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 20. Drivers
@DataClassName('DriverData')
class Drivers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  TextColumn get licenseNumber => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 21. Price Lists
@DataClassName('PriceListData')
class PriceLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get priceKobo => integer()();
  DateTimeColumn get effectiveFrom =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// 22. Payment Transactions
@DataClassName('PaymentTransactionData')
class PaymentTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get referenceId => integer()();
  TextColumn get type => text()(); // sale, purchase, expense
  IntColumn get amountKobo => integer()();
  TextColumn get method => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 23. Stock Transfers
@DataClassName('StockTransferData')
class StockTransfers extends Table {
  IntColumn get transferId => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get fromLocationId => integer().references(Warehouses, #id)();
  IntColumn get toLocationId => integer().references(Warehouses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, in_transit, received, cancelled
  IntColumn get initiatedBy => integer().references(Users, #id)();
  IntColumn get receivedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get initiatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get receivedAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 24. Stock Adjustments
@DataClassName('StockAdjustmentData')
class StockAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  IntColumn get quantityDiff => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 25. Activity Logs
@DataClassName('ActivityLogData')
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
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
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
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
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 28. Stock Transactions Ledger — source of truth for all stock movements
@DataClassName('StockTransactionData')
class StockTransactions extends Table {
  // UUID v4 text PK — caller must set before insert
  TextColumn get transactionId => text()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();

  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get locationId => integer().references(Warehouses, #id)();

  // Negative = outflow (sale, damage, transfer_out)
  // Positive = inflow  (purchase_received, return, transfer_in, adjustment)
  IntColumn get quantityDelta => integer()();

  // movement_type: sale | return | damage | transfer_out | transfer_in | purchase_received | adjustment
  TextColumn get movementType => text()();

  TextColumn get referenceId =>
      text().nullable()(); // orderId, transferId, etc.
  IntColumn get performedBy => integer().references(Users, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {transactionId};
}

// 29. Sessions
@DataClassName('SessionData')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get token => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// 30. Customer Wallet Transactions
@DataClassName('CustomerWalletTransactionData')
class CustomerWalletTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get amountDeltaKobo => integer()();
  TextColumn get type => text()(); // credit, debit, refund
  IntColumn get staffId => integer().references(Users, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 31. Customer Wallets
@DataClassName('CustomerWalletData')
class CustomerWallets extends Table {
  TextColumn get walletId => text()(); // UUID v4
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get customerId => integer().unique().references(Customers, #id)();
  TextColumn get currency => text().withDefault(const Constant('NGN'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {walletId};
}

// 32. Wallet Transactions
@DataClassName('WalletTransactionData')
class WalletTransactions extends Table {
  TextColumn get txnId => text()(); // UUID v4
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get walletId => text().references(CustomerWallets, #walletId)();
  TextColumn get type => text()(); // credit, debit
  IntColumn get amountKobo => integer()(); // always positive
  TextColumn get referenceType =>
      text()(); // topup_cash, topup_transfer, order_payment, refund, reward, fee
  TextColumn get referenceId => text().nullable()();
  IntColumn get performedBy => integer().references(Users, #id)();
  BoolColumn get customerVerified =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {txnId};
}

// 33. Saved Carts
@DataClassName('SavedCartData')
class SavedCarts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  TextColumn get name => text()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get cartData => text()(); // JSON-encoded cart items
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 34. Pending Crate Returns — short returns awaiting manager approval
@DataClassName('PendingCrateReturnData')
class PendingCrateReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get businessId => integer().nullable().references(Businesses, #id)();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get staffId => integer().references(Users, #id)();
  TextColumn get returnDataJson =>
      text()(); // JSON: [{crateGroupId,crateGroupName,expectedQty,returnedQty}]
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending/approved/rejected
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
}

// 36. Migration Events — records non-success outcomes of each migration step
// so failures stop being silent. Written by MigrationLogger.runStep.
@DataClassName('MigrationEventData')
class MigrationEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get version => integer()();
  TextColumn get step => text()();
  TextColumn get severity => text()(); // 'warning' | 'error'
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

// 35. Invites
@DataClassName('InviteData')
class Invites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text()();
  TextColumn get code => text().unique()(); // 8-char, case-insensitive
  TextColumn get role => text()();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  IntColumn get businessId => integer().references(Businesses, #id)();
  IntColumn get createdBy => integer().references(Users, #id)();
  TextColumn get inviteeName => text()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, accepted, expired, revoked
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get usedAt => dateTime().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
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
    SyncQueueOrphans,
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
    Businesses,
    Invites,
    MigrationEvents,
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

  /// Set once at login (and cleared on logout) by AuthService. DAOs that
  /// participate in the multi-tenant filter read through this so they don't
  /// have to depend on Riverpod or pass businessId explicitly.
  int? Function() businessIdResolver = () => null;
  int? get currentBusinessId => businessIdResolver();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      debugPrint('[AppDatabase] onCreate: Creating database tables...');
      await transaction(() => m.createAll());
      debugPrint('[AppDatabase] onCreate: DB setup complete.');
    },
    onUpgrade: (m, from, to) async {
      // Post-wipe installs (see lib/core/database/db_wipe.dart) always run
      // onCreate, never onUpgrade. Reaching this branch means the wipe was
      // bypassed or the marker file was tampered with.
      throw StateError(
        'Unexpected schema upgrade from v$from to v$to. '
        'Post-wipe installs should always run onCreate, never onUpgrade. '
        'Investigate db_wipe.dart and the cutover marker file.',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');

      // Schema self-heal audit. Compares Drift's declared schema against the
      // actual SQLite layout and re-runs ALTER TABLE / CREATE TABLE for any
      // drift.
      _lastSchemaAudit = await SchemaAudit(
        this,
        migratorFactory: () => createMigrator(),
      ).run(attemptHeal: true);
    },
  );

  SchemaAuditResult? _lastSchemaAudit;
  SchemaAuditResult? get lastSchemaAudit => _lastSchemaAudit;

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
  }
}

final database = AppDatabase();

/// Completer-guarded DB readiness flag.
/// Completes exactly once — safe to await from multiple screens concurrently.
final Completer<void> _dbCompleter = Completer<void>();

/// Public future for screens to await. Multiple awaits are safe (Completer
/// only completes once; subsequent awaits return instantly).
Future<void> get dbReady => _dbCompleter.future;

/// Call once from main.dart after the warmup query succeeds.
void markDbReady() {
  if (!_dbCompleter.isCompleted) _dbCompleter.complete();
}

/// Call from main.dart if the warmup query fails (screens still unblock).
void markDbReadyWithError([Object? error]) {
  if (!_dbCompleter.isCompleted) {
    _dbCompleter.completeError(error ?? 'DB init failed');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'reebaplus_pos.sqlite'));

    // Using standard NativeDatabase to avoid Isolate-related hangs on first launch.
    return NativeDatabase(
      file,
      logStatements: false, // Set to true for deep debugging
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA synchronous = NORMAL');
        db.execute('PRAGMA cache_size = -8000');
        db.execute('PRAGMA temp_store = MEMORY');
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}

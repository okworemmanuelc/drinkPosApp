// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daos.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
}

mixin _$InventoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $InventoryTable get inventory => attachedDatabase.inventory;
  InventoryDaoManager get managers => InventoryDaoManager(this);
}

class InventoryDaoManager {
  final _$InventoryDaoMixin _db;
  InventoryDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$InventoryTableTableManager get inventory =>
      $$InventoryTableTableManager(_db.attachedDatabase, _db.inventory);
}

mixin _$OrdersDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $CustomersTable get customers => attachedDatabase.customers;
  $UsersTable get users => attachedDatabase.users;
  $OrdersTable get orders => attachedDatabase.orders;
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $OrderItemsTable get orderItems => attachedDatabase.orderItems;
  $SavedCartsTable get savedCarts => attachedDatabase.savedCarts;
  OrdersDaoManager get managers => OrdersDaoManager(this);
}

class OrdersDaoManager {
  final _$OrdersDaoMixin _db;
  OrdersDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db.attachedDatabase, _db.orders);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$OrderItemsTableTableManager get orderItems =>
      $$OrderItemsTableTableManager(_db.attachedDatabase, _db.orderItems);
  $$SavedCartsTableTableManager get savedCarts =>
      $$SavedCartsTableTableManager(_db.attachedDatabase, _db.savedCarts);
}

mixin _$CustomersDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $CustomersTable get customers => attachedDatabase.customers;
  $UsersTable get users => attachedDatabase.users;
  $OrdersTable get orders => attachedDatabase.orders;
  $CustomerWalletTransactionsTable get customerWalletTransactions =>
      attachedDatabase.customerWalletTransactions;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $CustomerCrateBalancesTable get customerCrateBalances =>
      attachedDatabase.customerCrateBalances;
  $CustomerWalletsTable get customerWallets => attachedDatabase.customerWallets;
  $WalletTransactionsTable get walletTransactions =>
      attachedDatabase.walletTransactions;
  CustomersDaoManager get managers => CustomersDaoManager(this);
}

class CustomersDaoManager {
  final _$CustomersDaoMixin _db;
  CustomersDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db.attachedDatabase, _db.orders);
  $$CustomerWalletTransactionsTableTableManager
  get customerWalletTransactions =>
      $$CustomerWalletTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.customerWalletTransactions,
      );
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$CustomerCrateBalancesTableTableManager get customerCrateBalances =>
      $$CustomerCrateBalancesTableTableManager(
        _db.attachedDatabase,
        _db.customerCrateBalances,
      );
  $$CustomerWalletsTableTableManager get customerWallets =>
      $$CustomerWalletsTableTableManager(
        _db.attachedDatabase,
        _db.customerWallets,
      );
  $$WalletTransactionsTableTableManager get walletTransactions =>
      $$WalletTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.walletTransactions,
      );
}

mixin _$DeliveriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $PurchaseItemsTable get purchaseItems => attachedDatabase.purchaseItems;
  DeliveriesDaoManager get managers => DeliveriesDaoManager(this);
}

class DeliveriesDaoManager {
  final _$DeliveriesDaoMixin _db;
  DeliveriesDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$PurchaseItemsTableTableManager get purchaseItems =>
      $$PurchaseItemsTableTableManager(_db.attachedDatabase, _db.purchaseItems);
}

mixin _$ExpensesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExpenseCategoriesTable get expenseCategories =>
      attachedDatabase.expenseCategories;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $ExpensesTable get expenses => attachedDatabase.expenses;
  ExpensesDaoManager get managers => ExpensesDaoManager(this);
}

class ExpensesDaoManager {
  final _$ExpensesDaoMixin _db;
  ExpensesDaoManager(this._db);
  $$ExpenseCategoriesTableTableManager get expenseCategories =>
      $$ExpenseCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.expenseCategories,
      );
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db.attachedDatabase, _db.expenses);
}

mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
}

mixin _$ActivityLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $UsersTable get users => attachedDatabase.users;
  $ActivityLogsTable get activityLogs => attachedDatabase.activityLogs;
  ActivityLogDaoManager get managers => ActivityLogDaoManager(this);
}

class ActivityLogDaoManager {
  final _$ActivityLogDaoMixin _db;
  ActivityLogDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$ActivityLogsTableTableManager get activityLogs =>
      $$ActivityLogsTableTableManager(_db.attachedDatabase, _db.activityLogs);
}

mixin _$WarehousesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $UsersTable get users => attachedDatabase.users;
  WarehousesDaoManager get managers => WarehousesDaoManager(this);
}

class WarehousesDaoManager {
  final _$WarehousesDaoMixin _db;
  WarehousesDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
}

mixin _$NotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotificationsTable get notifications => attachedDatabase.notifications;
  NotificationsDaoManager get managers => NotificationsDaoManager(this);
}

class NotificationsDaoManager {
  final _$NotificationsDaoMixin _db;
  NotificationsDaoManager(this._db);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db.attachedDatabase, _db.notifications);
}

mixin _$StockLedgerDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $UsersTable get users => attachedDatabase.users;
  $StockTransactionsTable get stockTransactions =>
      attachedDatabase.stockTransactions;
  StockLedgerDaoManager get managers => StockLedgerDaoManager(this);
}

class StockLedgerDaoManager {
  final _$StockLedgerDaoMixin _db;
  StockLedgerDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.stockTransactions,
      );
}

mixin _$StockTransferDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $CategoriesTable get categories => attachedDatabase.categories;
  $CrateGroupsTable get crateGroups => attachedDatabase.crateGroups;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ManufacturersTable get manufacturers => attachedDatabase.manufacturers;
  $ProductsTable get products => attachedDatabase.products;
  $UsersTable get users => attachedDatabase.users;
  $StockTransfersTable get stockTransfers => attachedDatabase.stockTransfers;
  $StockTransactionsTable get stockTransactions =>
      attachedDatabase.stockTransactions;
  StockTransferDaoManager get managers => StockTransferDaoManager(this);
}

class StockTransferDaoManager {
  final _$StockTransferDaoMixin _db;
  StockTransferDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CrateGroupsTableTableManager get crateGroups =>
      $$CrateGroupsTableTableManager(_db.attachedDatabase, _db.crateGroups);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db.attachedDatabase, _db.manufacturers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StockTransfersTableTableManager get stockTransfers =>
      $$StockTransfersTableTableManager(
        _db.attachedDatabase,
        _db.stockTransfers,
      );
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.stockTransactions,
      );
}

mixin _$PendingCrateReturnsDaoMixin on DatabaseAccessor<AppDatabase> {
  $WarehousesTable get warehouses => attachedDatabase.warehouses;
  $CustomersTable get customers => attachedDatabase.customers;
  $UsersTable get users => attachedDatabase.users;
  $OrdersTable get orders => attachedDatabase.orders;
  $PendingCrateReturnsTable get pendingCrateReturns =>
      attachedDatabase.pendingCrateReturns;
  PendingCrateReturnsDaoManager get managers =>
      PendingCrateReturnsDaoManager(this);
}

class PendingCrateReturnsDaoManager {
  final _$PendingCrateReturnsDaoMixin _db;
  PendingCrateReturnsDaoManager(this._db);
  $$WarehousesTableTableManager get warehouses =>
      $$WarehousesTableTableManager(_db.attachedDatabase, _db.warehouses);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db.attachedDatabase, _db.orders);
  $$PendingCrateReturnsTableTableManager get pendingCrateReturns =>
      $$PendingCrateReturnsTableTableManager(
        _db.attachedDatabase,
        _db.pendingCrateReturns,
      );
}

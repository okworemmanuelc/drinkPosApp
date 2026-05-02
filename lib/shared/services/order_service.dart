import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';
import 'package:reebaplus_pos/shared/models/order.dart' as domain;

class OrderService {
  final AppDatabase _db;
  late final OrdersDao _ordersDao = _db.ordersDao;

  OrderService(this._db);

  /// Build an order from a UI cart and persist it atomically.
  ///
  /// Returns the human-readable order number (e.g. `ORD-000042`) — the
  /// checkout/receipt code displays this to the user.
  Future<String> addOrder({
    required String? customerId,
    required List<Map<String, dynamic>> cart,
    required int totalAmountKobo,
    required int amountPaidKobo,
    required String paymentType,
    String? staffId,
    String? warehouseId,
    int crateDepositPaidKobo = 0,
    String paymentSubType = 'cash',
  }) async {
    if (staffId == null || staffId.isEmpty) {
      throw ArgumentError('staffId is required');
    }
    if (warehouseId == null || warehouseId.isEmpty) {
      throw ArgumentError('warehouseId is required');
    }
    if (cart.isEmpty) {
      throw ArgumentError('cart is empty');
    }

    final orderId = UuidV7.generate();
    final orderNumber = await _ordersDao.generateOrderNumber();

    final dbPaymentType = _resolvePaymentType(
      paymentSubType: paymentSubType,
      amountPaidKobo: amountPaidKobo,
      totalAmountKobo: totalAmountKobo,
    );
    final walletDebitKobo = _resolveWalletDebit(
      dbPaymentType: dbPaymentType,
      amountPaidKobo: amountPaidKobo,
      totalAmountKobo: totalAmountKobo,
    );
    if (walletDebitKobo > 0 && (customerId == null || customerId.isEmpty)) {
      throw ArgumentError(
        'Wallet/credit/partial payments require a customerId',
      );
    }

    final items = _buildOrderItems(
      cart: cart,
      orderId: orderId,
      warehouseId: warehouseId,
    );

    final orderCompanion = OrdersCompanion.insert(
      id: Value(orderId),
      businessId: _ordersDao.requireBusinessId(),
      orderNumber: orderNumber,
      customerId: Value(customerId),
      totalAmountKobo: totalAmountKobo,
      netAmountKobo: totalAmountKobo,
      amountPaidKobo: Value(amountPaidKobo),
      paymentType: dbPaymentType,
      status: 'completed',
      staffId: Value(staffId),
      warehouseId: Value(warehouseId),
      crateDepositPaidKobo: Value(crateDepositPaidKobo),
      completedAt: Value(DateTime.now().toUtc()),
    );

    await _ordersDao.createOrder(
      order: orderCompanion,
      items: items,
      customerId: customerId,
      amountPaidKobo: amountPaidKobo,
      totalAmountKobo: totalAmountKobo,
      staffId: staffId,
      warehouseId: warehouseId,
      walletDebitKobo: walletDebitKobo,
      paymentMethod: _resolvePaymentMethod(paymentSubType),
    );

    return orderNumber;
  }

  String _resolvePaymentType({
    required String paymentSubType,
    required int amountPaidKobo,
    required int totalAmountKobo,
  }) {
    if (paymentSubType == 'wallet') return 'wallet';
    if (amountPaidKobo <= 0) return 'credit';
    if (amountPaidKobo < totalAmountKobo) return 'mixed';
    return 'cash';
  }

  int _resolveWalletDebit({
    required String dbPaymentType,
    required int amountPaidKobo,
    required int totalAmountKobo,
  }) {
    switch (dbPaymentType) {
      case 'wallet':
      case 'credit':
        return totalAmountKobo;
      case 'mixed':
        return totalAmountKobo - amountPaidKobo;
      default:
        return 0;
    }
  }

  String _resolvePaymentMethod(String paymentSubType) {
    if (paymentSubType == 'wallet') return 'wallet';
    if (paymentSubType == 'transfer') return 'transfer';
    if (paymentSubType == 'card' || paymentSubType == 'pos') {
      return paymentSubType;
    }
    return 'cash';
  }

  List<OrderItemsCompanion> _buildOrderItems({
    required List<Map<String, dynamic>> cart,
    required String orderId,
    required String warehouseId,
  }) {
    final businessId = _ordersDao.requireBusinessId();
    return cart
        .map((item) {
          final productId = item['id'] as String?;
          if (productId == null || productId.isEmpty) {
            throw ArgumentError(
              'Cart contains an item without a product id (Quick Sale '
              'items cannot be saved as orders).',
            );
          }

          final qty = (item['qty'] as num).toInt();
          // Prefer the integer kobo snapshot; fall back to the legacy double
          // 'price' (Naira) for carts seeded before line-version tracking.
          final unitPriceKobo =
              (item['unitPriceKobo'] as int?) ??
              ((item['price'] as num).toDouble() * 100).round();
          final buyingPriceKobo = (item['buyingPriceKobo'] as int?) ?? 0;
          final totalKobo = unitPriceKobo * qty;
          final version = item['version'] as int?;

          final snapshot = jsonEncode({
            'name': item['name'],
            'unitPriceKobo': unitPriceKobo,
            if (version != null) 'version': version,
          });

          return OrderItemsCompanion.insert(
            businessId: businessId,
            orderId: orderId,
            productId: productId,
            warehouseId: warehouseId,
            quantity: qty,
            unitPriceKobo: unitPriceKobo,
            buyingPriceKobo: Value(buyingPriceKobo),
            totalKobo: totalKobo,
            priceSnapshot: Value(snapshot),
          );
        })
        .toList(growable: false);
  }

  Stream<List<domain.Order>> watchPendingOrders() {
    return _ordersDao.watchPendingOrders().map<List<domain.Order>>(
      (list) => list.map<domain.Order>((d) => OrderService.fromDb(d)).toList(),
    );
  }

  Stream<List<domain.Order>> watchAllOrders() {
    return _ordersDao.watchAllOrders().map<List<domain.Order>>(
      (list) => list.map<domain.Order>((d) => OrderService.fromDb(d)).toList(),
    );
  }

  Stream<List<domain.Order>> watchCompletedOrders() {
    return _ordersDao.watchCompletedOrders().map<List<domain.Order>>(
      (list) => list.map<domain.Order>((d) => OrderService.fromDb(d)).toList(),
    );
  }

  Stream<List<OrderWithItems>> watchAllOrdersWithItems() {
    return _ordersDao.watchAllOrdersWithItems();
  }

  Future<List<CartStaleItem>> checkCartStaleness(List<CartLineSnapshot> lines) {
    return _ordersDao.checkCartStaleness(lines);
  }

  static domain.Order fromDb(OrderData data) {
    return domain.Order(
      id: data.id.toString(),
      customerId: data.customerId?.toString(),
      customerName: 'Customer ${data.customerId}',
      items: [],
      totalAmount: data.totalAmountKobo / 100.0,
      amountPaid: data.amountPaidKobo / 100.0,
      customerWallet: 0.0,
      paymentMethod: data.paymentType,
      createdAt: data.createdAt,
      status: data.status,
    );
  }

  Future<void> markAsCompleted(String orderId, String staffId) {
    return _ordersDao.markCompleted(orderId, staffId);
  }

  Future<void> markAsCancelled(String orderId, String reason, String staffId) {
    return _ordersDao.markCancelled(orderId, reason, staffId);
  }

  Future<void> assignRider(String orderId, String riderName) {
    return _ordersDao.assignRider(orderId, riderName);
  }

  Future<List<UserData>> getRiders() {
    return _db.warehousesDao.getRiders();
  }
}

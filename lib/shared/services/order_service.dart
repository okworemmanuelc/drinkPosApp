import 'package:drift/drift.dart';
import '../models/order.dart' as domain;
import '../../core/database/app_database.dart';
import '../../core/database/daos.dart';

class OrderService {
  final OrdersDao _ordersDao = database.ordersDao;

  OrderService();

  Future<String> addOrder({
    required int? customerId,
    required List<Map<String, dynamic>> cart,
    required int totalAmountKobo,
    required int amountPaidKobo,
    required String paymentType,
    int? staffId,
  }) async {
    final orderItems = cart
        .where((item) => item['id'] != null)
        .map((item) {
      final productId = item['id'] is int ? item['id'] as int : int.parse(item['id'].toString());
      final warehouseId = item['warehouseId'] is int ? item['warehouseId'] as int : 1;
      
      return OrderItemsCompanion(
        productId: Value(productId),
        warehouseId: Value(warehouseId),
        quantity: Value((item['qty'] as num).toInt()),
        unitPriceKobo: Value(((item['price'] as num) * 100).round()),
        totalKobo: Value(((item['total'] as num? ?? ((item['qty'] as num) * (item['price'] as num))) * 100).round()),
      );
    }).toList();

    return await _ordersDao.createOrder(
      order: OrdersCompanion(
        customerId: Value(customerId),
        totalAmountKobo: Value(totalAmountKobo),
        netAmountKobo: Value(totalAmountKobo),
        paymentType: Value(paymentType),
        status: const Value('pending'),
        staffId: Value(staffId),
      ),
      items: orderItems,
      customerId: customerId,
      paymentType: paymentType,
      amountPaidKobo: amountPaidKobo,
    );
  }

  Stream<List<domain.Order>> watchPendingOrders() {
    return _ordersDao.watchPendingOrders().map<List<domain.Order>>((list) => list.map<domain.Order>((OrderData d) => OrderService.fromDb(d)).toList());
  }

  Stream<List<domain.Order>> watchAllOrders() {
    return _ordersDao.watchAllOrders().map<List<domain.Order>>((list) => list.map<domain.Order>((OrderData d) => OrderService.fromDb(d)).toList());
  }

  Stream<List<domain.Order>> watchCompletedOrders() {
    return _ordersDao.watchCompletedOrders().map<List<domain.Order>>((list) => list.map<domain.Order>((OrderData d) => OrderService.fromDb(d)).toList());
  }

  Stream<List<OrderWithItems>> watchAllOrdersWithItems() {
    return _ordersDao.watchAllOrdersWithItems();
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

  Future<void> markAsCompleted(int orderId, int staffId) {
    return _ordersDao.markCompleted(orderId, staffId);
  }

  Future<void> markAsCancelled(int orderId, String reason, int staffId) {
    return _ordersDao.markCancelled(orderId, reason, staffId);
  }

  Future<void> assignRider(int orderId, String riderName) {
    return _ordersDao.assignRider(orderId, riderName);
  }
}

final orderService = OrderService();

import 'package:flutter/foundation.dart';
import '../models/order.dart';

class OrderService extends ValueNotifier<List<Order>> {
  OrderService() : super(_initialOrders);

  static final List<Order> _initialOrders = [
    Order(
      id: 'o1',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      cart: [
        {'name': 'Heineken 60cl', 'qty': 20.0, 'price': 800},
        {'name': 'Star Radler', 'qty': 10.0, 'price': 600},
      ],
      subtotal: 22000.0,
      crateDeposit: 2000.0,
      total: 24000.0,
      paymentMethod: 'Partial Cash',
      cashReceived: 10000.0,
    ),
    Order(
      id: 'o2',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      cart: [
        {'name': 'Life Beer', 'qty': 30.0, 'price': 700},
      ],
      subtotal: 21000.0,
      crateDeposit: 0.0,
      total: 21000.0,
      paymentMethod: 'Credit Sale',
    ),
    Order(
      id: 'o3',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      timestamp: DateTime.now().subtract(const Duration(days: 10)),
      cart: [
        {'name': 'Tiger Beer', 'qty': 15.0, 'price': 700},
      ],
      subtotal: 10500.0,
      crateDeposit: 1500.0,
      total: 12000.0,
      paymentMethod: 'Card',
    ),
    Order(
      id: 'o4',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      timestamp: DateTime.now().subtract(const Duration(days: 15)),
      cart: [
        {'name': 'Legend Stout', 'qty': 5.0, 'price': 800},
      ],
      subtotal: 4000.0,
      crateDeposit: 0.0,
      total: 4000.0,
      paymentMethod: 'Full Cash',
      cashReceived: 4000.0,
    ),
  ];

  void addOrder(Order order) {
    value = [...value, order];
  }

  List<Order> getOrdersByCustomer(String customerId) {
    final list = value.where((o) => o.customerId == customerId).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}

final orderService = OrderService();

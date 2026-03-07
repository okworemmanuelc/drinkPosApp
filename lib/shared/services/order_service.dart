import 'package:flutter/foundation.dart';
import '../models/order.dart';

class OrderService extends ValueNotifier<List<Order>> {
  OrderService() : super(_initialOrders);

  // We seed this with the previous dummy orders formatted for the new structure,
  // plus a pending order so the UI can be tested.
  static final List<Order> _initialOrders = [
    Order(
      id: 'o1',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      customerAddress: 'Block A, Alaba Market',
      customerPhone: '08012345678',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      completedAt: DateTime.now().subtract(const Duration(days: 1)),
      items: [
        {
          'name': 'Heineken 60cl',
          'qty': 20.0,
          'price': 800,
          'needsEmptyCrate': true,
        },
        {
          'name': 'Star Radler',
          'qty': 10.0,
          'price': 600,
          'needsEmptyCrate': false,
        },
      ],
      subtotal: 22000.0,
      crateDeposit: 2000.0,
      totalAmount: 24000.0,
      paymentMethod: 'Partial Cash',
      amountPaid: 10000.0,
      balance: 14000.0,
      status: 'completed',
    ),
    Order(
      id: 'o2',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      customerAddress: 'Block A, Alaba Market',
      customerPhone: '08012345678',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      items: [
        {
          'name': 'Life Beer',
          'qty': 30.0,
          'price': 700,
          'needsEmptyCrate': false,
        },
      ],
      subtotal: 21000.0,
      crateDeposit: 0.0,
      totalAmount: 21000.0,
      paymentMethod: 'Credit Sale',
      amountPaid: 0.0,
      balance: 21000.0,
      status: 'completed',
    ),
    Order(
      id: '1709426',
      customerId: 'c1',
      customerName: 'Alhaji Musa',
      customerAddress: 'Block A, Alaba Market',
      customerPhone: '08012345678',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      items: [
        {
          'name': 'Tiger Beer',
          'qty': 15.0,
          'price': 700,
          'needsEmptyCrate': true,
        },
      ],
      subtotal: 10500.0,
      crateDeposit: 1500.0,
      totalAmount: 12000.0,
      paymentMethod: 'Card',
      amountPaid: 12000.0,
      balance: 0.0,
      status: 'pending',
    ),
  ];

  void addOrder(Order order) {
    value = [...value, order];
  }

  void markAsCompleted(String orderId) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = value[idx].copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );
      final newList = List<Order>.from(value);
      newList[idx] = updated;
      value = newList;
    }
  }

  void markAsCancelled(String orderId) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = value[idx].copyWith(
        status: 'cancelled',
        completedAt: DateTime.now(),
      );
      final newList = List<Order>.from(value);
      newList[idx] = updated;
      value = newList;
    }
  }

  List<Order> getPending() {
    final pending = value.where((o) => o.status == 'pending').toList();
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pending;
  }

  List<Order> getCompleted() {
    final completed = value.where((o) => o.status == 'completed').toList();
    completed.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return completed;
  }

  List<Order> getCancelled() {
    final cancelled = value.where((o) => o.status == 'cancelled').toList();
    cancelled.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return cancelled;
  }

  List<Order> getOrdersByCustomer(String customerId) {
    final list = value.where((o) => o.customerId == customerId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

final orderService = OrderService();

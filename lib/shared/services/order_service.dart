import 'package:flutter/foundation.dart';
import '../../core/utils/number_format.dart';
import '../../features/customers/data/services/customer_service.dart';
import '../../shared/services/activity_log_service.dart';
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
          'crateGroupName': 'NB Plc',
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
      customerWallet: 14000.0,
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
      customerWallet: 21000.0,
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
          'crateGroupName': 'NB Plc',
        },
      ],
      subtotal: 10500.0,
      crateDeposit: 1500.0,
      totalAmount: 12000.0,
      paymentMethod: 'Card',
      amountPaid: 12000.0,
      customerWallet: 0.0,
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

      // Step F: Auto-update crate balance on sale completion
      if (updated.customerId != null) {
        final Map<String, int> cratesAdded = {};
        for (final item in updated.items) {
          if (item['needsEmptyCrate'] == true) {
            final groupName = item['crateGroupName'] as String? ?? 'Other';
            cratesAdded[groupName] = (cratesAdded[groupName] ?? 0) + (item['qty'] as num).toInt();
          }
        }
        if (cratesAdded.isNotEmpty) {
          customerService.addCratesToBalance(updated.customerId!, cratesAdded);
        }
      }

      // Step G: Log event (Ensure this is moved here or updated in UI)
      // Actually the UI handles logging for now, but I'll add the service-level logging for consistency if needed.
      // The user wants the log to include: timestamp, customer name, order ref, rider name.
    }
  }

  void assignRider(String orderId, String riderName) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = value[idx].copyWith(riderName: riderName);
      final newList = List<Order>.from(value);
      newList[idx] = updated;
      value = newList;

      activityLogService.logAction(
        'Rider Assigned',
        'Rider $riderName assigned to order ${updated.id} for ${updated.customerName}',
        relatedEntityId: updated.id,
        relatedEntityType: 'order',
      );
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

  void refundOrder(String orderId, {bool toWallet = true}) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final order = value[idx];
      // Only allow refunding cancelled orders that haven't been refunded yet
      if (order.status == 'cancelled') {
        final updated = order.copyWith(status: 'Refunded');
        final newList = List<Order>.from(value);
        newList[idx] = updated;
        value = newList;

        final refundMethod = toWallet ? 'Wallet' : 'Cash';

        // Process wallet refund if applicable
        if (toWallet && order.customerId != null && order.amountPaid > 0) {
          customerService.refundToWallet(
            order.customerId!,
            order.amountPaid,
            'Refund (#$refundMethod) for order #${order.id}',
          );
        }

        activityLogService.logAction(
          'Order Refunded ($refundMethod)',
          'Order ${order.id} for ${order.customerName} was refunded to $refundMethod (${formatCurrency(order.amountPaid)}).',
          relatedEntityId: order.id,
          relatedEntityType: 'order',
        );
      }
    }
  }

  void addReprint(String orderId) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = value[idx].copyWith(
        reprints: [...value[idx].reprints, DateTime.now()],
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
    final cancelled = value.where((o) => o.status == 'cancelled' || o.status == 'Refunded').toList();
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

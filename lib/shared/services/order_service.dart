import 'package:flutter/foundation.dart';
import '../../core/database/repositories/order_repository.dart';
import '../../core/utils/number_format.dart';
import '../../features/customers/data/services/customer_service.dart';
import '../../shared/services/activity_log_service.dart';
import '../../shared/services/notification_service.dart';
import '../models/order.dart';

class OrderService extends ValueNotifier<List<Order>> {
  OrderService() : super([]);

  Future<void> init() async {
    value = await orderRepository.getAll();
  }

  void addOrder(Order order) {
    value = [...value, order];
    orderRepository.insert(order);
    notificationService.createNotification(
      'new_order',
      'New order #${order.id} received for ${order.customerName}',
      linkedRecordId: order.id,
    );
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
      orderRepository.update(updated);

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
    }
  }

  void assignRider(String orderId, String riderName) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = value[idx].copyWith(riderName: riderName);
      final newList = List<Order>.from(value);
      newList[idx] = updated;
      value = newList;
      orderRepository.update(updated);
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
      orderRepository.update(updated);
    }
  }

  void refundOrder(String orderId, {bool toWallet = true}) {
    final idx = value.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final order = value[idx];
      if (order.status == 'cancelled') {
        final updated = order.copyWith(status: 'Refunded');
        final newList = List<Order>.from(value);
        newList[idx] = updated;
        value = newList;
        orderRepository.update(updated);

        final refundMethod = toWallet ? 'Wallet' : 'Cash';
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
      orderRepository.update(updated);
    }
  }

  List<Order> getPending() {
    final pending = value.where((o) => o.status == 'pending').toList();
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pending;
  }

  List<Order> getCompleted() {
    final completed = value.where((o) => o.status == 'completed').toList();
    completed.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    return completed;
  }

  List<Order> getCancelled() {
    final cancelled = value.where((o) => o.status == 'cancelled' || o.status == 'Refunded').toList();
    cancelled.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    return cancelled;
  }

  List<Order> getOrdersByCustomer(String customerId) {
    final list = value.where((o) => o.customerId == customerId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

final orderService = OrderService();

import 'package:flutter/widgets.dart';
import '../../../../core/database/repositories/customer_repository.dart';
import '../../../../shared/services/activity_log_service.dart';
import '../models/customer.dart';
import '../models/payment.dart';

class CustomerService extends ValueNotifier<List<Customer>> {
  CustomerService() : super([]);

  Future<void> init() async {
    value = await customerRepository.getAll();
  }

  List<Customer> getAll() => List.unmodifiable(value);

  Customer? getById(String id) {
    try {
      return value.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void addCustomer(Customer customer) {
    value = [...value, customer];
    customerRepository.insert(customer);
    activityLogService.logAction(
      'Customer Created',
      'Added new customer: ${customer.name}',
      relatedEntityId: customer.id,
      relatedEntityType: 'customer',
    );
  }

  void updateCustomer(Customer updatedCustomer) {
    final index = value.indexWhere((c) => c.id == updatedCustomer.id);
    if (index != -1) {
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;
      customerRepository.update(updatedCustomer);
      activityLogService.logAction(
        'Customer Updated',
        'Updated details for customer: ${updatedCustomer.name}',
        relatedEntityId: updatedCustomer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void addPayment(String customerId, Payment payment) {
    final customer = getById(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        payments: [...customer.payments, payment],
        customerWallet: customer.customerWallet + payment.amount,
      );
      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;
      customerRepository.update(updatedCustomer);
      activityLogService.logAction(
        'Payment Added',
        'Added payment of ₦${payment.amount.toStringAsFixed(2)} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void addCratesToBalance(String customerId, Map<String, int> cratesAdded) {
    final customer = getById(customerId);
    if (customer != null) {
      final newBalance = Map<String, int>.from(customer.emptyCratesBalance);
      cratesAdded.forEach((group, qty) {
        newBalance[group] = (newBalance[group] ?? 0) + qty;
      });
      final updated = customer.copyWith(emptyCratesBalance: newBalance);
      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updated;
      value = newList;
      customerRepository.update(updated);
      activityLogService.logAction(
        'Crates Dispatched',
        'Added $cratesAdded empty crates to balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void updateEmptyCratesBalance(String customerId, Map<String, int> cratesReturned) {
    final customer = getById(customerId);
    if (customer != null) {
      final newBalance = Map<String, int>.from(customer.emptyCratesBalance);
      cratesReturned.forEach((group, qty) {
        newBalance[group] = ((newBalance[group] ?? 0) - qty).clamp(0, 9999);
      });
      final updated = customer.copyWith(emptyCratesBalance: newBalance);
      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updated;
      value = newList;
      customerRepository.update(updated);
      activityLogService.logAction(
        'Crates Returned',
        'Updated empty crates balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void updateWalletLimit(String customerId, double newLimit) {
    final customer = getById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(walletLimit: newLimit);
      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updated;
      value = newList;
      customerRepository.update(updated);
      activityLogService.logAction(
        'Limit Updated',
        'Updated wallet limit to ₦${newLimit.abs().toStringAsFixed(0)} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void refundToWallet(String customerId, double amount, String note) {
    final customer = getById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        customerWallet: customer.customerWallet + amount,
      );
      updateCustomer(updated);
      activityLogService.logAction(
        'Wallet Refunded',
        'Refunded ₦${amount.toStringAsFixed(2)} to ${customer.name}. Note: $note',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }
}

final CustomerService customerService = CustomerService();

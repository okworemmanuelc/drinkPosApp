import 'package:flutter/widgets.dart';
import '../../../../shared/services/activity_log_service.dart';
import '../models/customer.dart';
import '../models/payment.dart';

class CustomerService extends ValueNotifier<List<Customer>> {
  CustomerService() : super(_initialCustomers);

  static final List<Customer> _initialCustomers = [
    Customer(
      id: 'c1',
      name: 'Alhaji Musa',
      addressText: '12 Borno Way, Maiduguri',
      googleMapsLocation: '12 Borno Way',
      customerWallet: 15000.0,
      customerGroup: CustomerGroup.retailer,
      isWalkIn: false,
    ),
    Customer(
      id: 'c2',
      name: 'Mama Chioma',
      addressText: '45 Market Road, Maiduguri',
      googleMapsLocation: '45 Market Road',
      customerWallet: 0.0,
      customerGroup: CustomerGroup.retailer,
      isWalkIn: false,
    ),
    Customer(
      id: 'c3',
      name: 'Cold Room Express',
      addressText: '8 Industrial Layout, Maiduguri',
      googleMapsLocation: '8 Industrial Layout',
      customerWallet: -7500.0,
      customerGroup: CustomerGroup.retailer,
      isWalkIn: false,
    ),
  ];

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
      final updatedPayments = [...customer.payments, payment];
      final newBalance = customer.customerWallet + payment.amount;

      final updatedCustomer = customer.copyWith(
        payments: updatedPayments,
        customerWallet: newBalance,
      );

      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;

      activityLogService.logAction(
        'Payment Added',
        'Added payment of ₦${payment.amount.toStringAsFixed(2)} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void addCratesToBalance(
    String customerId,
    Map<String, int> cratesAdded,
  ) {
    final customer = getById(customerId);
    if (customer != null) {
      final newCratesBalance = Map<String, int>.from(
        customer.emptyCratesBalance,
      );

      cratesAdded.forEach((crateGroup, qty) {
        final currentQty = newCratesBalance[crateGroup] ?? 0;
        newCratesBalance[crateGroup] = currentQty + qty;
      });

      final updatedCustomer = customer.copyWith(
        emptyCratesBalance: newCratesBalance,
      );

      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;

      activityLogService.logAction(
        'Crates Dispatched',
        'Added $cratesAdded empty crates to balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  void updateEmptyCratesBalance(
    String customerId,
    Map<String, int> cratesReturned,
  ) {
    final customer = getById(customerId);
    if (customer != null) {
      final newCratesBalance = Map<String, int>.from(
        customer.emptyCratesBalance,
      );

      cratesReturned.forEach((crateGroup, qtyReturned) {
        final currentQty = newCratesBalance[crateGroup] ?? 0;
        newCratesBalance[crateGroup] = (currentQty - qtyReturned).clamp(
          0,
          9999,
        );
      });

      final updatedCustomer = customer.copyWith(
        emptyCratesBalance: newCratesBalance,
      );

      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;

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
      final updatedCustomer = customer.copyWith(walletLimit: newLimit);
      final index = value.indexWhere((c) => c.id == customerId);
      final newList = List<Customer>.from(value);
      newList[index] = updatedCustomer;
      value = newList;

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
      final updatedCustomer = customer.copyWith(
        customerWallet: customer.customerWallet + amount,
      );
      updateCustomer(updatedCustomer);

      activityLogService.logAction(
        'Wallet Refunded',
        'Refunded ₦${amount.toStringAsFixed(2)} to ${customer.name}. Note: $note',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }
}

// Global instance available app-wide
final CustomerService customerService = CustomerService();

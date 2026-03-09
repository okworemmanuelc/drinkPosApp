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
      outstandingBalance: 15000.0,
      customerGroup: CustomerGroup.retailer,
      isWalkIn: false,
    ),
    Customer(
      id: 'c2',
      name: 'Mama Chioma',
      addressText: '45 Market Road, Maiduguri',
      googleMapsLocation: '45 Market Road',
      outstandingBalance: 0.0,
      customerGroup: CustomerGroup.retailer,
      isWalkIn: false,
    ),
    Customer(
      id: 'c3',
      name: 'Cold Room Express',
      addressText: '8 Industrial Layout, Maiduguri',
      googleMapsLocation: '8 Industrial Layout',
      outstandingBalance: -7500.0,
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
      final newBalance = customer.outstandingBalance + payment.amount;

      final updatedCustomer = customer.copyWith(
        payments: updatedPayments,
        outstandingBalance: newBalance,
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
}

// Global instance available app-wide
final CustomerService customerService = CustomerService();

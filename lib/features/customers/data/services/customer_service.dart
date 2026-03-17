import 'package:flutter/widgets.dart';
import '../../../../shared/services/activity_log_service.dart';
import '../../../../core/database/app_database.dart';
import '../models/customer.dart';
import '../models/payment.dart';

class CustomerService extends ValueNotifier<List<Customer>> {
  CustomerService() : super([]) {
    _init();
  }

  void _init() {
    database.customersDao.watchAllCustomers().listen((dataList) {
      value = dataList.map((d) => Customer.fromDb(d)).toList();
    });
  }

  List<Customer> getAll() => List.unmodifiable(value);

  Customer? getById(String id) {
    try {
      return value.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCustomer(Customer customer) async {
    await activityLogService.logAction(
      'Customer Created',
      'Added new customer: ${customer.name}',
      relatedEntityType: 'customer',
    );
  }

  Future<void> updateCustomer(Customer updatedCustomer) async {
    await activityLogService.logAction(
      'Customer Updated',
      'Updated details for customer: ${updatedCustomer.name}',
      relatedEntityId: updatedCustomer.id,
      relatedEntityType: 'customer',
    );
  }

  Future<void> addPayment(String customerId, Payment payment) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Payment Added',
        'Added payment of ₦${payment.amount.round()} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> addCratesToBalance(
    String customerId,
    Map<String, int> cratesAdded,
  ) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Crates Dispatched',
        'Added $cratesAdded empty crates to balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> updateEmptyCratesBalance(
    String customerId,
    Map<String, int> cratesReturned,
  ) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Crates Returned',
        'Updated empty crates balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> updateWalletLimit(String customerId, double newLimit) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Limit Updated',
        'Updated wallet limit to ₦${newLimit.abs().toStringAsFixed(0)} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> refundToWallet(String customerId, double amount, String note) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Wallet Refunded',
        'Refunded ₦${amount.round()} to ${customer.name}. Note: $note',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }
}

// Global instance available app-wide
final CustomerService customerService = CustomerService();

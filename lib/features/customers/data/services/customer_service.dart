import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
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

  Customer? getById(int id) {
    try {
      return value.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCustomer(Customer customer) async {
    await database.customersDao.addCustomer(CustomersCompanion.insert(
      name: customer.name,
      phone: Value(customer.phone),
      address: Value(customer.addressText),
      googleMapsLocation: Value(customer.googleMapsLocation),
      customerGroup: Value(customer.customerGroup.name),
    ));
    
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
      relatedEntityId: updatedCustomer.id.toString(),
      relatedEntityType: 'customer',
    );
  }

  Future<void> addPayment(int customerId, Payment payment) async {
    final customer = getById(customerId);
    if (customer == null) return;

    final amountKobo = (payment.amount * 100).round();
    await database.customersDao.updateWalletBalance(
      customerId: customerId,
      deltaKobo: amountKobo,
      type: 'credit',
      referenceType: 'topup_cash',
      note: payment.note,
      staffId: 1, // TODO: Use actual staff ID
    );

    await activityLogService.logAction(
      'Payment Added',
      'Added payment of ₦${payment.amount.round()} for ${customer.name}',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }

  Future<void> addCratesToBalance(
    int customerId,
    Map<String, int> cratesAdded,
  ) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Crates Dispatched',
        'Added $cratesAdded empty crates to balance for ${customer.name}',
        relatedEntityId: customer.id.toString(),
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> updateEmptyCratesBalance(
    int customerId,
    Map<String, int> cratesReturned,
  ) async {
    final customer = getById(customerId);
    if (customer != null) {
      await activityLogService.logAction(
        'Crates Returned',
        'Updated empty crates balance for ${customer.name}',
        relatedEntityId: customer.id.toString(),
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> updateWalletLimit(int customerId, double newLimit) async {
    final customer = getById(customerId);
    if (customer == null) return;

    final limitKobo = (newLimit * 100).round();
    await database.customersDao.updateWalletLimit(customerId, limitKobo);

    await activityLogService.logAction(
      'Limit Updated',
      'Updated wallet limit to ₦${newLimit.abs().toStringAsFixed(0)} for ${customer.name}',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }

  Future<void> refundToWallet(int customerId, double amount, String note) async {
    final customer = getById(customerId);
    if (customer == null) return;

    final amountKobo = (amount * 100).round();
    await database.customersDao.updateWalletBalance(
      customerId: customerId,
      deltaKobo: amountKobo,
      type: 'credit',
      referenceType: 'refund',
      note: note,
      staffId: 1, // TODO: Use actual staff ID
    );

    await activityLogService.logAction(
      'Wallet Refunded',
      'Refunded ₦${amount.round()} to ${customer.name}. Note: $note',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }
}

// Global instance available app-wide
final CustomerService customerService = CustomerService();

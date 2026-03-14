import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart' show Value;
import '../../../../shared/services/activity_log_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/database/app_database.dart';
import '../models/customer.dart';
import '../models/payment.dart';

class CustomerService extends ValueNotifier<List<Customer>> {
  CustomerService() : super([]) {
    _init();
  }

  void _init() {
    database.customersDao.watchAllCustomers().listen((dataList) {
      value = dataList;
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
    final companion = CustomersCompanion.insert(
      name: customer.name,
      phone: Value(customer.phone),
      address: Value(customer.addressText),
      walletBalanceKobo: Value(customer.walletBalanceKobo),
      walletLimitKobo: Value(customer.walletLimitKobo),
    );
    await database.customersDao.addCustomer(companion);

    await activityLogService.logAction(
      'Customer Created',
      'Added new customer: ${customer.name}',
      relatedEntityType: 'customer',
    );
  }

  Future<void> updateCustomer(Customer updatedCustomer) async {
    final idInt = int.tryParse(updatedCustomer.id);
    if (idInt == null) return;

    await (database.update(database.customers)..where((t) => t.id.equals(idInt))).write(
      CustomersCompanion(
        name: Value(updatedCustomer.name),
        phone: Value(updatedCustomer.phone),
        address: Value(updatedCustomer.addressText),
        walletLimitKobo: Value(updatedCustomer.walletLimitKobo),
      ),
    );

    await activityLogService.logAction(
      'Customer Updated',
      'Updated details for customer: ${updatedCustomer.name}',
      relatedEntityId: updatedCustomer.id,
      relatedEntityType: 'customer',
    );
  }

  Future<void> addPayment(String customerId, Payment payment) async {
    final idInt = int.tryParse(customerId);
    if (idInt == null) return;

    final customer = getById(customerId);
    if (customer != null) {
      final amountKobo = (payment.amount * 100).round();
      
      await database.customersDao.updateWalletBalance(
        customerId: idInt,
        deltaKobo: amountKobo,
        type: 'credit',
        staffId: authService.currentUser?.id ?? 1,
        note: payment.note,
      );

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
    final idInt = int.tryParse(customerId);
    if (idInt == null) return;

    final customer = getById(customerId);
    if (customer != null) {
      for (final entry in cratesAdded.entries) {
        // Find crate group ID from name or use default
        // For now, let's assume crate group IDs are 1 and 2
        final groupId = entry.key.contains('24') ? 1 : 2;
        await database.customersDao.updateCrateBalance(idInt, groupId, entry.value);
      }

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
    final idInt = int.tryParse(customerId);
    if (idInt == null) return;

    final customer = getById(customerId);
    if (customer != null) {
      for (final entry in cratesReturned.entries) {
        final groupId = entry.key.contains('24') ? 1 : 2;
        await database.customersDao.updateCrateBalance(idInt, groupId, -entry.value);
      }

      await activityLogService.logAction(
        'Crates Returned',
        'Updated empty crates balance for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> updateWalletLimit(String customerId, double newLimit) async {
    final idInt = int.tryParse(customerId);
    if (idInt == null) return;

    final customer = getById(customerId);
    if (customer != null) {
      final limitKobo = (newLimit * 100).round();
      await (database.update(database.customers)..where((t) => t.id.equals(idInt))).write(
        CustomersCompanion(walletLimitKobo: Value(limitKobo)),
      );

      await activityLogService.logAction(
        'Limit Updated',
        'Updated wallet limit to ₦${newLimit.abs().toStringAsFixed(0)} for ${customer.name}',
        relatedEntityId: customer.id,
        relatedEntityType: 'customer',
      );
    }
  }

  Future<void> refundToWallet(String customerId, double amount, String note) async {
    final idInt = int.tryParse(customerId);
    if (idInt == null) return;

    final customer = getById(customerId);
    if (customer != null) {
      final amountKobo = (amount * 100).round();
      await database.customersDao.updateWalletBalance(
        customerId: idInt,
        deltaKobo: amountKobo,
        type: 'refund',
        staffId: authService.currentUser?.id ?? 1,
        note: note,
      );

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

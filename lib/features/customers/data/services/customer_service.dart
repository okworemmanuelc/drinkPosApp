import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
import 'package:reebaplus_pos/shared/services/activity_log_service.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/features/customers/data/models/customer.dart';
import 'package:reebaplus_pos/features/customers/data/models/payment.dart';

class CustomerService extends ValueNotifier<List<Customer>> {
  final AppDatabase _db;
  final ActivityLogService _log;

  CustomerService(this._db, this._log) : super([]) {
    _init();
  }

  void _init() {
    _db.customersDao.watchAllCustomers().listen((dataList) {
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

  Future<Customer?> addCustomer(Customer customer) async {
    final newId = await _db.customersDao.addCustomer(
      CustomersCompanion.insert(
        name: customer.name,
        phone: Value(customer.phone),
        address: Value(customer.addressText),
        googleMapsLocation: Value(customer.googleMapsLocation),
        customerGroup: Value(customer.customerGroup.name),
        warehouseId: Value(customer.warehouseId),
      ),
    );

    await _log.logAction(
      'Customer Created',
      'Added new customer: ${customer.name}',
      relatedEntityType: 'customer',
    );

    final data = await _db.customersDao.findById(newId);
    return data != null ? Customer.fromDb(data) : null;
  }

  Future<void> updateCustomer(Customer updatedCustomer) async {
    await _log.logAction(
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
    await _db.customersDao.updateWalletBalance(
      customerId: customerId,
      amountKobo: amountKobo,
      type: 'credit',
      referenceType: 'topup_cash',
      note: payment.note,
      staffId: 1, // TODO: Use actual staff ID
    );

    await _log.logAction(
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
      await _log.logAction(
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
      await _log.logAction(
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
    await _db.customersDao.updateWalletLimit(customerId, limitKobo);

    await _log.logAction(
      'Limit Updated',
      'Updated wallet limit to ₦${newLimit.abs().toStringAsFixed(0)} for ${customer.name}',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }

  Future<void> refundToWallet(
    int customerId,
    double amount,
    String note,
  ) async {
    final customer = getById(customerId);
    if (customer == null) return;

    final amountKobo = (amount * 100).round();
    await _db.customersDao.updateWalletBalance(
      customerId: customerId,
      amountKobo: amountKobo,
      type: 'credit',
      referenceType: 'refund',
      note: note,
      staffId: 1, // TODO: Use actual staff ID
    );

    await _log.logAction(
      'Wallet Refunded',
      'Refunded ₦${amount.round()} to ${customer.name}. Note: $note',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }

  Future<void> updateWalletBalance(
    int customerId,
    double amount,
    String note,
  ) async {
    final customer = getById(customerId);
    if (customer == null) return;

    final amountKobo = (amount * 100).round();
    await _db.customersDao.updateWalletBalance(
      customerId: customerId,
      amountKobo: amountKobo,
      type: 'credit',
      referenceType: 'topup_cash',
      note: note,
      staffId: 1, // TODO: Use actual staff ID
    );

    await _log.logAction(
      'Wallet Updated',
      'Added ₦${amount.round()} to ${customer.name}\'s wallet. Note: $note',
      relatedEntityId: customer.id.toString(),
      relatedEntityType: 'customer',
    );
  }
}


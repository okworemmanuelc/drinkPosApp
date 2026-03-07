import 'package:flutter/widgets.dart';

import '../models/payment.dart';

class PaymentService extends ValueNotifier<List<Payment>> {
  PaymentService() : super(_initialPayments);

  static final List<Payment> _initialPayments = [];

  List<Payment> getAll() => List.unmodifiable(value);

  List<Payment> getByPeriod(String period) {
    if (period == 'All Time') return getAll();

    final now = DateTime.now();
    return value.where((p) {
      final diff = now.difference(p.date);
      if (period == 'Day' || period == 'Today') {
        return diff.inDays == 0 && now.day == p.date.day;
      }
      if (period == 'Week' || period == 'This Week') return diff.inDays <= 7;
      if (period == 'Month' || period == 'This Month') return diff.inDays <= 30;
      if (period == 'Year' || period == 'This Year') return diff.inDays <= 365;
      if (period == 'To Date') return true;
      return true;
    }).toList();
  }

  List<Payment> getBySupplier(String supplierName) {
    return value.where((p) => p.supplierName == supplierName).toList();
  }

  double getTotalForPeriod(String period) {
    final payments = getByPeriod(period);
    return payments.fold(0.0, (sum, p) => sum + p.amount);
  }

  void addPayment(Payment payment) {
    value = [...value, payment];
  }

  void deletePayment(String id) {
    value = value.where((p) => p.id != id).toList();
  }
}

final PaymentService paymentService = PaymentService();

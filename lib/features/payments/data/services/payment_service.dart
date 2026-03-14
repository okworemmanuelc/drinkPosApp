import 'package:flutter/widgets.dart';
import '../../../../core/database/repositories/payment_repository.dart';
import '../models/payment.dart';

class PaymentService extends ValueNotifier<List<Payment>> {
  PaymentService() : super([]);

  Future<void> init() async {
    value = await paymentRepository.getAll();
  }

  List<Payment> getAll() => List.unmodifiable(value);

  List<Payment> getByPeriod(String period) {
    if (period == 'All Time') return getAll();
    final now = DateTime.now();
    return value.where((p) {
      final diff = now.difference(p.date);
      if (period == 'Day' || period == 'Today') return diff.inDays == 0 && now.day == p.date.day;
      if (period == 'Week' || period == 'This Week') return diff.inDays <= 7;
      if (period == 'Month' || period == 'This Month') return diff.inDays <= 30;
      if (period == 'Year' || period == 'This Year') return diff.inDays <= 365;
      return true;
    }).toList();
  }

  List<Payment> getBySupplier(String supplierName) =>
      value.where((p) => p.supplierName == supplierName).toList();

  double getTotalForPeriod(String period) =>
      getByPeriod(period).fold(0.0, (sum, p) => sum + p.amount);

  void addPayment(Payment payment) {
    value = [...value, payment];
    paymentRepository.insert(payment);
  }

  void deletePayment(String id) {
    value = value.where((p) => p.id != id).toList();
    paymentRepository.delete(id);
  }
}

final PaymentService paymentService = PaymentService();

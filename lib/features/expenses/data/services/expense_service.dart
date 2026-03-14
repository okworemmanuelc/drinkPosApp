import 'package:flutter/foundation.dart';
import '../../../../core/database/repositories/expense_repository.dart';
import '../models/expense.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../core/utils/number_format.dart';

class ExpenseService extends ValueNotifier<List<Expense>> {
  ExpenseService() : super([]);

  Future<void> init() async {
    value = await expenseRepository.getAll();
  }

  List<Expense> getAll() => List.unmodifiable(value);

  List<Expense> getByPeriod(String period) {
    if (period == 'All Time') return getAll();
    final now = DateTime.now();
    return value.where((e) {
      final diff = now.difference(e.date);
      if (period == 'Day' || period == 'Today') return diff.inDays == 0 && now.day == e.date.day;
      if (period == 'Week' || period == 'This Week') return diff.inDays <= 7;
      if (period == 'Month' || period == 'This Month') return diff.inDays <= 30;
      if (period == 'Year' || period == 'This Year') return diff.inDays <= 365;
      return true;
    }).toList();
  }

  List<Expense> getByCategory(String category) =>
      value.where((e) => e.category == category).toList();

  double getTotalForPeriod(String period) =>
      getByPeriod(period).fold(0.0, (sum, e) => sum + e.amount);

  double getTotalByCategory(String category, String period) =>
      getByPeriod(period).where((e) => e.category == category).fold(0.0, (sum, e) => sum + e.amount);

  double getAnnualProjection() {
    final now = DateTime.now();
    final currentYear = value.where((e) => e.date.year == now.year);
    if (currentYear.isEmpty) return 0.0;
    final total = currentYear.fold(0.0, (sum, e) => sum + e.amount);
    return (total / now.month.toDouble()) * 12;
  }

  void addExpense(Expense expense) {
    value = [...value, expense];
    expenseRepository.insert(expense);
    if (expense.amount >= 50000) {
      notificationService.createNotification(
        'large_expense',
        'Large expense recorded: ${formatCurrency(expense.amount)} for ${expense.category}',
        linkedRecordId: expense.id,
      );
    }
  }

  void deleteExpense(String id) {
    value = value.where((e) => e.id != id).toList();
    expenseRepository.delete(id);
  }
}

final ExpenseService expenseService = ExpenseService();

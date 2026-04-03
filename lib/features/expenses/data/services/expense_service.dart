import 'package:flutter/foundation.dart';
import 'package:reebaplus_pos/features/expenses/data/models/expense.dart';
import 'package:reebaplus_pos/shared/services/notification_service.dart';
import 'package:reebaplus_pos/core/utils/number_format.dart';

class ExpenseService extends ValueNotifier<List<Expense>> {
  ExpenseService() : super(_initialExpenses);

  static final List<Expense> _initialExpenses = [];

  List<Expense> getAll() => List.unmodifiable(value);

  List<Expense> getByPeriod(String period) {
    if (period == 'All Time') return getAll();

    final now = DateTime.now();
    return value.where((e) {
      final diff = now.difference(e.date);
      if (period == 'Day' || period == 'Today') {
        return diff.inDays == 0 && now.day == e.date.day;
      }
      if (period == 'Week' || period == 'This Week') return diff.inDays <= 7;
      if (period == 'Month' || period == 'This Month') return diff.inDays <= 30;
      if (period == 'Year' || period == 'This Year') return diff.inDays <= 365;
      if (period == 'To Date') return true;
      return true;
    }).toList();
  }

  List<Expense> getByCategory(String category) {
    return value.where((e) => e.category == category).toList();
  }

  double getTotalForPeriod(String period) {
    return getByPeriod(period).fold(0.0, (sum, e) => sum + e.amount);
  }

  double getTotalByCategory(String category, String period) {
    return getByPeriod(period)
        .where((e) => e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getAnnualProjection() {
    final now = DateTime.now();
    final currentYearExpenses = value.where((e) => e.date.year == now.year);
    if (currentYearExpenses.isEmpty) return 0.0;

    final totalSpentThisYear = currentYearExpenses.fold(
      0.0,
      (sum, e) => sum + e.amount,
    );

    // We assume 1 month elapsed if it's January to avoid division by zero or overly high projections.
    final monthsElapsed = now.month.toDouble();
    return (totalSpentThisYear / monthsElapsed) * 12;
  }

  Future<void> addExpense(Expense expense) async {
    value = [...value, expense];
    if (expense.amount >= 50000) {
      await notificationService.createNotification(
        'large_expense',
        'Large expense recorded: ${formatCurrency(expense.amount)} for ${expense.category}',
        linkedRecordId: expense.id,
      );
    }
  }

  void deleteExpense(String id) {
    value = value.where((e) => e.id != id).toList();
  }
}

final ExpenseService expenseService = ExpenseService();

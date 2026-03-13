import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../core/utils/number_format.dart';

class ExpenseService extends ValueNotifier<List<Expense>> {
  ExpenseService() : super(_initialExpenses);

  static final List<Expense> _initialExpenses = [
    Expense(id: 'e1', description: 'Diesel for Generator', amount: 15000, category: 'Fuel', paymentMethod: 'Cash', date: DateTime.now().subtract(const Duration(days: 1)), createdAt: DateTime.now().subtract(const Duration(days: 1)), recordedBy: 'Alice Smith'),
    Expense(id: 'e2', description: 'Shop Rent (Monthly)', amount: 50000, category: 'Rent', paymentMethod: 'Bank Transfer', date: DateTime.now().subtract(const Duration(days: 10)), createdAt: DateTime.now().subtract(const Duration(days: 10)), recordedBy: 'John Okoro'),
    Expense(id: 'e3', description: 'Staff Lunch', amount: 3000, category: 'Staff Welfare', paymentMethod: 'Cash', date: DateTime.now().subtract(const Duration(days: 2)), createdAt: DateTime.now().subtract(const Duration(days: 2)), recordedBy: 'Mary Adams'),
    Expense(id: 'e4', description: 'Electricity Bill', amount: 12000, category: 'Utilities', paymentMethod: 'POS', date: DateTime.now().subtract(const Duration(days: 20)), createdAt: DateTime.now().subtract(const Duration(days: 20)), recordedBy: 'Alice Smith'),
    Expense(id: 'e5', description: 'Generator Maintenance', amount: 8000, category: 'Maintenance', paymentMethod: 'Cash', date: DateTime.now().subtract(const Duration(days: 45)), createdAt: DateTime.now().subtract(const Duration(days: 45)), recordedBy: 'Bob Johnson'),
    Expense(id: 'e6', description: 'Van Fuel', amount: 5000, category: 'Fuel', paymentMethod: 'Cash', date: DateTime.now().subtract(const Duration(hours: 5)), createdAt: DateTime.now().subtract(const Duration(hours: 5)), recordedBy: 'Sani Bello'),
    Expense(id: 'e7', description: 'Office Supplies', amount: 2500, category: 'Stationery', paymentMethod: 'Cash', date: DateTime.now().subtract(const Duration(days: 120)), createdAt: DateTime.now().subtract(const Duration(days: 120)), recordedBy: 'Mary Adams'),
    Expense(id: 'e8', description: 'Promotion Flyers', amount: 10000, category: 'Marketing', paymentMethod: 'Bank Transfer', date: DateTime.now().subtract(const Duration(days: 5)), createdAt: DateTime.now().subtract(const Duration(days: 5)), recordedBy: 'John Okoro'),
  ];

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

  void addExpense(Expense expense) {
    value = [...value, expense];
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
  }
}

final ExpenseService expenseService = ExpenseService();

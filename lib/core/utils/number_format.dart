import 'package:intl/intl.dart';

/// Formats a number with comma separators.
/// Handles negative numbers by prepending the minus sign.
/// e.g. fmtNumber(5000) → '5,000'
/// e.g. fmtNumber(-5000) → '-5,000'
String fmtNumber(num n) {
  final formatter = NumberFormat('#,###', 'en_US');
  return formatter.format(n);
}

/// Formats a double as currency with Naira sign and exactly 2 decimal places.
/// e.g. formatCurrency(5000.5) → '₦5,000.50'
/// e.g. formatCurrency(-5000.5) → '-₦5,000.50'
String formatCurrency(num n) {
  final isNegative = n < 0;
  final formatter = NumberFormat('#,##0.00', 'en_US');
  final formatted = formatter.format(n.abs());
  return isNegative ? '-₦$formatted' : '₦$formatted';
}

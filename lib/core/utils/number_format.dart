/// Formats a number with comma separators.
/// Handles negative numbers by prepending the minus sign.
/// e.g. fmtNumber(5000) → '5,000'
/// e.g. fmtNumber(-5000) → '-5,000'
String fmtNumber(num n) {
  final isNegative = n < 0;
  final val = n.abs().toInt();
  String result;
  if (val >= 1000) {
    final s = val.toString();
    final buf = StringBuffer();
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    result = buf.toString();
  } else {
    result = val.toString();
  }
  return isNegative ? '-$result' : result;
}

/// Formats a double as currency with Nair sign.
/// e.g. formatCurrency(5000.5) → '₦5,000'
String formatCurrency(num n) {
  return '₦${fmtNumber(n.toInt())}';
}

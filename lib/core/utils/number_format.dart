/// Formats an integer with comma separators.
/// e.g. fmtNumber(5000) → '5,000'
String fmtNumber(int n) {
  if (n >= 1000) {
    final s = n.toString();
    final buf = StringBuffer();
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
  return n.toString();
}

/// Formats a double as currency with Nair sign.
/// e.g. formatCurrency(5000.5) → '₦5,000'
String formatCurrency(num n) {
  return '₦${fmtNumber(n.toInt())}';
}

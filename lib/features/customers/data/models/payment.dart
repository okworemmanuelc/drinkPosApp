class Payment {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String? note;

  Payment({
    required this.id,
    required this.amount,
    required this.timestamp,
    this.note,
  });
}

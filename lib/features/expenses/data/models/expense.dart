class Expense {
  final String id;
  final String category;
  final double amount;
  final String paymentMethod;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final String recordedBy;
  final String? reference;
  final String? receiptPath;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    this.description,
    required this.date,
    required this.createdAt,
    required this.recordedBy,
    this.reference,
    this.receiptPath,
  });

  Expense copyWith({
    String? id,
    String? category,
    double? amount,
    String? paymentMethod,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? recordedBy,
    String? reference,
    String? receiptPath,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      recordedBy: recordedBy ?? this.recordedBy,
      reference: reference ?? this.reference,
      receiptPath: receiptPath ?? this.receiptPath,
    );
  }
}

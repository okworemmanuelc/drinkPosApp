class Payment {
  final String id;
  final String? supplierId;
  final String supplierName;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final String? deliveryId;
  final DateTime date;
  final DateTime createdAt;

  Payment({
    required this.id,
    this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.deliveryId,
    required this.date,
    required this.createdAt,
  });

  Payment copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    double? amount,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
    String? deliveryId,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      deliveryId: deliveryId ?? this.deliveryId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

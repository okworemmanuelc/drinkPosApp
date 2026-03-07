class Delivery {
  final String id;
  final String? customerId;
  final String customerName;
  final String customerAddress;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String receiptBarcode;

  Delivery({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.receiptBarcode,
  });

  Delivery copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerAddress,
    List<Map<String, dynamic>>? items,
    double? totalAmount,
    double? amountPaid,
    double? balance,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? receiptBarcode,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      balance: balance ?? this.balance,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      receiptBarcode: receiptBarcode ?? this.receiptBarcode,
    );
  }
}

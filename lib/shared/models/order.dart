class Order {
  final String id;
  final String? customerId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final List<Map<String, dynamic>> items;
  final double subtotal; // Included from old Order
  final double crateDeposit; // Included from old Order
  final double totalAmount;
  final double amountPaid;
  final double customerWallet;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String status;
  final List<DateTime> reprints;
  final String riderName;

  Order({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerAddress = '',
    this.customerPhone = '',
    required this.items,
    this.subtotal = 0.0,
    this.crateDeposit = 0.0,
    required this.totalAmount,
    required this.amountPaid,
    required this.customerWallet,
    required this.paymentMethod,
    required this.createdAt,
    this.completedAt,
    this.status = 'pending',
    this.reprints = const [],
    this.riderName = 'Pick-up Order',
  });

  Order copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? crateDeposit,
    double? totalAmount,
    double? amountPaid,
    double? customerWallet,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? completedAt,
    String? status,
    List<DateTime>? reprints,
    String? riderName,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? List.from(this.items),
      subtotal: subtotal ?? this.subtotal,
      crateDeposit: crateDeposit ?? this.crateDeposit,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      customerWallet: customerWallet ?? this.customerWallet,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      reprints: reprints ?? this.reprints,
      riderName: riderName ?? this.riderName,
    );
  }
}

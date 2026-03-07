class Order {
  final String id;
  final String? customerId;
  final String? customerName;
  final DateTime timestamp;
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;
  final String paymentMethod;
  final double? cashReceived;

  Order({
    required this.id,
    this.customerId,
    this.customerName,
    required this.timestamp,
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
    required this.paymentMethod,
    this.cashReceived,
  });
}

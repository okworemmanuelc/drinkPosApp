import 'payment.dart';

enum CustomerGroup { distributor, bulkBreaker, retailer }

class Customer {
  final String id;
  final String name;
  final String addressText;
  final String googleMapsLocation;
  final String? phone;
  final double customerWallet;
  final double walletLimit;
  final Map<String, int> emptyCratesBalance;
  final List<Payment> payments;
  final List<String> orderIds;
  final DateTime createdAt;
  final CustomerGroup customerGroup;
  final bool isWalkIn;

  Customer({
    required this.id,
    required this.name,
    required this.addressText,
    required this.googleMapsLocation,
    this.phone,
    this.customerWallet = 0.0,
    this.walletLimit = 0.0,
    Map<String, int>? emptyCratesBalance,
    List<Payment>? payments,
    List<String>? orderIds,
    DateTime? createdAt,
    this.customerGroup = CustomerGroup.retailer,
    this.isWalkIn = false,
  }) : emptyCratesBalance = emptyCratesBalance ?? {},
       payments = payments ?? [],
       orderIds = orderIds ?? [],
       createdAt = createdAt ?? DateTime.now();

  Customer copyWith({
    String? id,
    String? name,
    String? addressText,
    String? googleMapsLocation,
    String? phone,
    double? customerWallet,
    double? walletLimit,
    Map<String, int>? emptyCratesBalance,
    List<Payment>? payments,
    List<String>? orderIds,
    DateTime? createdAt,
    CustomerGroup? customerGroup,
    bool? isWalkIn,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      addressText: addressText ?? this.addressText,
      googleMapsLocation: googleMapsLocation ?? this.googleMapsLocation,
      phone: phone ?? this.phone,
      customerWallet: customerWallet ?? this.customerWallet,
      walletLimit: walletLimit ?? this.walletLimit,
      emptyCratesBalance:
          emptyCratesBalance ?? Map.from(this.emptyCratesBalance),
      payments: payments ?? List.from(this.payments),
      orderIds: orderIds ?? List.from(this.orderIds),
      createdAt: createdAt ?? this.createdAt,
      customerGroup: customerGroup ?? this.customerGroup,
      isWalkIn: isWalkIn ?? this.isWalkIn,
    );
  }

  /// Increases the wallet balance by a given amount and records the transaction
  Customer fundWallet(double amount, {String note = 'Wallet Funded'}) {
    final payment = Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      timestamp: DateTime.now(),
      note: note,
    );
    return copyWith(
      customerWallet: customerWallet + amount,
      payments: [...payments, payment],
    );
  }
}

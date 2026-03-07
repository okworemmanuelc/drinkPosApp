import 'payment.dart';

class Customer {
  final String id;
  final String name;
  final String addressText;
  final String googleMapsLocation;
  final String? phone;
  final double outstandingBalance;
  final Map<String, int> emptyCratesBalance;
  final List<Payment> payments;
  final List<String> orderIds;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.addressText,
    required this.googleMapsLocation,
    this.phone,
    this.outstandingBalance = 0.0,
    Map<String, int>? emptyCratesBalance,
    List<Payment>? payments,
    List<String>? orderIds,
    DateTime? createdAt,
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
    double? outstandingBalance,
    Map<String, int>? emptyCratesBalance,
    List<Payment>? payments,
    List<String>? orderIds,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      addressText: addressText ?? this.addressText,
      googleMapsLocation: googleMapsLocation ?? this.googleMapsLocation,
      phone: phone ?? this.phone,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      emptyCratesBalance:
          emptyCratesBalance ?? Map.from(this.emptyCratesBalance),
      payments: payments ?? List.from(this.payments),
      orderIds: orderIds ?? List.from(this.orderIds),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

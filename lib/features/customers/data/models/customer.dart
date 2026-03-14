import 'package:onafia_pos/core/database/app_database.dart';
import 'payment.dart';

enum CustomerGroup { distributor, bulkBreaker, retailer }

class Customer {
  final String id;
  final String name;
  final String addressText;
  final String googleMapsLocation;
  final String? phone;
  final int walletBalanceKobo;
  final int walletLimitKobo;
  final DateTime createdAt;
  final CustomerGroup customerGroup;
  final bool isWalkIn;
  final Map<String, int> emptyCratesBalance;
  final List<Payment> payments;

  Customer({
    required this.id,
    required this.name,
    required this.addressText,
    required this.googleMapsLocation,
    this.phone,
    this.walletBalanceKobo = 0,
    this.walletLimitKobo = 0,
    DateTime? createdAt,
    this.customerGroup = CustomerGroup.retailer,
    this.isWalkIn = false,
    this.emptyCratesBalance = const {},
    this.payments = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  double get customerWallet => walletBalanceKobo / 100.0;
  double get walletLimit => walletLimitKobo / 100.0;

  Customer copyWith({
    String? id,
    String? name,
    String? addressText,
    String? googleMapsLocation,
    String? phone,
    int? walletBalanceKobo,
    int? walletLimitKobo,
    DateTime? createdAt,
    CustomerGroup? customerGroup,
    bool? isWalkIn,
    Map<String, int>? emptyCratesBalance,
    List<Payment>? payments,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      addressText: addressText ?? this.addressText,
      googleMapsLocation: googleMapsLocation ?? this.googleMapsLocation,
      phone: phone ?? this.phone,
      walletBalanceKobo: walletBalanceKobo ?? this.walletBalanceKobo,
      walletLimitKobo: walletLimitKobo ?? this.walletLimitKobo,
      createdAt: createdAt ?? this.createdAt,
      customerGroup: customerGroup ?? this.customerGroup,
      isWalkIn: isWalkIn ?? this.isWalkIn,
      emptyCratesBalance: emptyCratesBalance ?? this.emptyCratesBalance,
      payments: payments ?? this.payments,
    );
  }

  static Customer fromDb(CustomerData data) {
    return Customer(
      id: data.id.toString(),
      name: data.name,
      addressText: data.address ?? 'N/A',
      googleMapsLocation: data.address ?? 'N/A',
      phone: data.phone,
      walletBalanceKobo: data.walletBalanceKobo,
      walletLimitKobo: data.walletLimitKobo,
      createdAt: DateTime.now(), // TODO: Add createdAt to DB table
      customerGroup: CustomerGroup.retailer, // TODO: Add customerGroup to DB table
      isWalkIn: data.id == -1,
      emptyCratesBalance: const {}, // TODO: Fetch from CrateBalances table
      payments: const [], // TODO: Fetch from Payments table
    );
  }

  static Customer walkIn() => Customer(
    id: 'walk-in',
    name: 'Walk-in Customer',
    addressText: 'N/A',
    googleMapsLocation: 'N/A',
    isWalkIn: true,
    emptyCratesBalance: const {},
    payments: const [],
  );
}

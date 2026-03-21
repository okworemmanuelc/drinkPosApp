import 'package:ribaplus_pos/core/database/app_database.dart';
import 'payment.dart';

enum CustomerGroup { retailer, wholesaler }

class Customer {
  final int id;
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
  final int? warehouseId;

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
    this.warehouseId,
  }) : createdAt = createdAt ?? DateTime.now();

  double get customerWallet => walletBalanceKobo / 100.0;
  double get walletLimit => walletLimitKobo / 100.0;

  Customer copyWith({
    int? id,
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
    int? warehouseId,
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
      warehouseId: warehouseId ?? this.warehouseId,
    );
  }

  static Customer fromDb(CustomerData data) {
    CustomerGroup group = CustomerGroup.retailer;
    try {
      group = CustomerGroup.values.firstWhere((e) => e.name == data.customerGroup);
    } catch (_) {}

    return Customer(
      id: data.id,
      name: data.name,
      addressText: data.address ?? 'N/A',
      googleMapsLocation: data.googleMapsLocation ?? 'N/A',
      phone: data.phone,
      walletBalanceKobo: data.walletBalanceKobo,
      walletLimitKobo: data.walletLimitKobo,
      createdAt: data.createdAt,
      customerGroup: group,
      isWalkIn: data.id == -1,
      emptyCratesBalance: const {}, // TODO: Fetch from CrateBalances table
      payments: const [], // TODO: Fetch from Payments table
      warehouseId: data.warehouseId,
    );
  }

  static Customer walkIn() => Customer(
    id: -1,
    name: 'Walk-in Customer',
    addressText: 'N/A',
    googleMapsLocation: 'N/A',
    isWalkIn: true,
    emptyCratesBalance: const {},
    payments: const [],
  );
}

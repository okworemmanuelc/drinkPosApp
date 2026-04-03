import 'package:reebaplus_pos/core/utils/stock_calculator.dart';

class DeliveryItem {
  final String productId; // InventoryItem.id (empty for manual)
  final String productName;
  final String supplierName;
  final String? crateGroupLabel;
  final double unitPrice;
  final double quantity;

  DeliveryItem({
    required this.productId,
    required this.productName,
    required this.supplierName,
    this.crateGroupLabel,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => stockValue(unitPrice, quantity);
}

class Delivery {
  final String id;
  final String supplierName;
  final DateTime deliveredAt;
  final List<DeliveryItem> items;
  final double totalValue;
  final String status; // "pending" | "confirmed"

  Delivery({
    required this.id,
    required this.supplierName,
    required this.deliveredAt,
    required this.items,
    required this.totalValue,
    required this.status,
  });
}

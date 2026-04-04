// InventoryItem model
// TODO: define InventoryItem class
import 'package:flutter/material.dart';

class InventoryItem {
  final String id;
  String productName;
  String subtitle;
  String? supplierId;
  String? crateGroupName;
  bool needsEmptyCrate;
  IconData icon;
  Color color;
  Map<String, double> warehouseStock; // warehouseId -> quantity
  double lowStockThreshold;

  // Pricing fields
  double? sellingPrice;
  double? buyingPrice;
  double? retailPrice;
  double? bulkBreakerPrice;
  double? distributorPrice;

  String? category;
  String? pairedCrateItemId;
  String? imagePath;
  String? manufacturer;
  String? size; // 'big' | 'medium' | 'small'

  InventoryItem({
    required this.id,
    required this.productName,
    required this.subtitle,
    this.supplierId,
    this.crateGroupName,
    this.needsEmptyCrate = false,
    required this.icon,
    required this.color,
    this.warehouseStock = const {},
    this.lowStockThreshold = 5,
    this.sellingPrice,
    this.buyingPrice,
    this.retailPrice,
    this.bulkBreakerPrice,
    this.distributorPrice,
    this.category,
    this.pairedCrateItemId,
    this.imagePath,
    this.manufacturer,
    this.size,
  });

  double get totalStock =>
      warehouseStock.values.fold(0.0, (sum, val) => sum + val);

  // Helper to get stock for a specific warehouse
  double getStockForWarehouse(String warehouseId) =>
      warehouseStock[warehouseId] ?? 0.0;

  InventoryItem copyWith({
    String? id,
    String? productName,
    String? subtitle,
    String? supplierId,
    String? crateGroupName,
    bool? needsEmptyCrate,
    IconData? icon,
    Color? color,
    Map<String, double>? warehouseStock,
    double? lowStockThreshold,
    double? sellingPrice,
    double? buyingPrice,
    double? retailPrice,
    double? bulkBreakerPrice,
    double? distributorPrice,
    String? category,
    String? pairedCrateItemId,
    String? imagePath,
    String? manufacturer,
    String? size,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      subtitle: subtitle ?? this.subtitle,
      supplierId: supplierId ?? this.supplierId,
      crateGroupName: crateGroupName ?? this.crateGroupName,
      needsEmptyCrate: needsEmptyCrate ?? this.needsEmptyCrate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      warehouseStock: warehouseStock ?? this.warehouseStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      bulkBreakerPrice: bulkBreakerPrice ?? this.bulkBreakerPrice,
      distributorPrice: distributorPrice ?? this.distributorPrice,
      category: category ?? this.category,
      pairedCrateItemId: pairedCrateItemId ?? this.pairedCrateItemId,
      imagePath: imagePath ?? this.imagePath,
      manufacturer: manufacturer ?? this.manufacturer,
      size: size ?? this.size,
    );
  }
}

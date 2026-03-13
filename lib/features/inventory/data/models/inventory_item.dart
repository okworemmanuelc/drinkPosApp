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
  });

  double get totalStock =>
      warehouseStock.values.fold(0.0, (sum, val) => sum + val);

  // Helper to get stock for a specific warehouse
  double getStockForWarehouse(String warehouseId) =>
      warehouseStock[warehouseId] ?? 0.0;
}

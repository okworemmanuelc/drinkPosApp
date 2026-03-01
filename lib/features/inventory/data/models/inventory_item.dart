// InventoryItem model
// TODO: define InventoryItem class
import 'package:flutter/material.dart';

class InventoryItem {
  final String id;
  String productName;
  String subtitle;
  String supplierId;
  IconData icon;
  Color color;
  double stock;
  double lowStockThreshold;

  InventoryItem({
    required this.id,
    required this.productName,
    required this.subtitle,
    required this.supplierId,
    required this.icon,
    required this.color,
    this.stock = 0,
    this.lowStockThreshold = 5,
  });
}

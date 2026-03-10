// kInventoryItems, kSuppliers, kCrateStocks, kInventoryLogs
// TODO: populate inventory state data
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'models/crate_group.dart';
import 'models/inventory_item.dart';
import 'models/crate_stock.dart';
import 'models/inventory_log.dart';

final List<CrateStock> kCrateStocks = [
  CrateStock(group: CrateGroup.nbPlc, available: 24),
  CrateStock(group: CrateGroup.guinness, available: 12),
  CrateStock(group: CrateGroup.cocaCola, available: 8),
  CrateStock(group: CrateGroup.premium, available: 0),
];

final List<InventoryItem> kInventoryItems = [
  InventoryItem(
    id: 'i1',
    productName: 'Star Lager',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: Color(0xFFF59E0B),
    stock: 18,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i2',
    productName: 'Heineken',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: Color(0xFF10B981),
    stock: 42,
    lowStockThreshold: 10,
  ),
  InventoryItem(
    id: 'i3',
    productName: 'Guinness',
    subtitle: 'Stout',
    supplierId: 's2',
    icon: FontAwesomeIcons.wineGlassEmpty,
    color: Color(0xFF334155),
    stock: 6,
    lowStockThreshold: 8,
  ),
  InventoryItem(
    id: 'i4',
    productName: 'Goldberg',
    subtitle: 'Keg',
    supplierId: 's1',
    icon: FontAwesomeIcons.database,
    color: Color(0xFFD97706),
    stock: 3,
    lowStockThreshold: 4,
  ),
  InventoryItem(
    id: 'i5',
    productName: 'Tiger Beer',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: Color(0xFF3B82F6),
    stock: 30,
    lowStockThreshold: 10,
  ),
  InventoryItem(
    id: 'i6',
    productName: '33 Export',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: Color(0xFFEA580C),
    stock: 2,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i7',
    productName: 'Desperados',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: Color(0xFFE11D48),
    stock: 14,
    lowStockThreshold: 6,
  ),
  InventoryItem(
    id: 'i8',
    productName: 'Legend Stout',
    subtitle: 'Keg',
    supplierId: 's2',
    icon: FontAwesomeIcons.database,
    color: Color(0xFF475569),
    stock: 1,
    lowStockThreshold: 3,
  ),
  InventoryItem(
    id: 'i9',
    productName: 'Life Lager',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: Color(0xFFEAB308),
    stock: 9,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i10',
    productName: 'Maltina',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: Color(0xFF78350F),
    stock: 22,
    lowStockThreshold: 8,
  ),
  InventoryItem(
    id: 'i11',
    productName: 'Amstel Malta',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: Color(0xFFC2410C),
    stock: 17,
    lowStockThreshold: 8,
  ),
];

final List<InventoryLog> kInventoryLogs = [];

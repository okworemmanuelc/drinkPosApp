import 'package:flutter/widgets.dart';
import '../models/supplier.dart';
import '../models/crate_group.dart';

class SupplierService extends ValueNotifier<List<Supplier>> {
  SupplierService() : super(_initialSuppliers);

  static final List<Supplier> _initialSuppliers = [
    Supplier(
      id: 's1',
      name: 'Nigerian Breweries Plc',
      crateGroup: CrateGroup.nbPlc,
      contactDetails: 'Plot 2, Igamu House, Lagos. Tel: 01-2703300',
      supplierWallet: -150000.0, // Debt to supplier
    ),
    Supplier(
      id: 's2',
      name: 'Guinness Nigeria',
      crateGroup: CrateGroup.guinness,
      contactDetails: '24 Oba Akran Ave, Ikeja, Lagos. Tel: 01-2709100',
      supplierWallet: 50000.0, // Credit with supplier
    ),
    Supplier(
      id: 's3',
      name: 'Coca-Cola Nigeria',
      crateGroup: CrateGroup.cocaCola,
      contactDetails: '1 Industrial Estate, Oyo State. Tel: 0800-265-22652',
      supplierWallet: 0.0,
    ),
  ];

  List<Supplier> getAll() => List.unmodifiable(value);

  Supplier? getById(String id) {
    try {
      return value.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  void addSupplier(Supplier supplier) {
    value = [...value, supplier];
  }

  void updateSupplier(Supplier updatedSupplier) {
    final index = value.indexWhere((s) => s.id == updatedSupplier.id);
    if (index != -1) {
      final newList = List<Supplier>.from(value);
      newList[index] = updatedSupplier;
      value = newList;
    }
  }
}

final SupplierService supplierService = SupplierService();

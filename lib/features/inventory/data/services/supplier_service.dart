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
    ),
    Supplier(
      id: 's2',
      name: 'Guinness Nigeria',
      crateGroup: CrateGroup.guinness,
    ),
    Supplier(
      id: 's3',
      name: 'Coca-Cola Nigeria',
      crateGroup: CrateGroup.cocaCola,
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

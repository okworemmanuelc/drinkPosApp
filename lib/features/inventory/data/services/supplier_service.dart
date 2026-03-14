import 'package:flutter/widgets.dart';
import '../../../../core/database/repositories/supplier_repository.dart';
import '../models/supplier.dart';

class SupplierService extends ValueNotifier<List<Supplier>> {
  SupplierService() : super([]);

  Future<void> init() async {
    value = await supplierRepository.getAll();
  }

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
    supplierRepository.insert(supplier);
  }

  void updateSupplier(Supplier updatedSupplier) {
    final index = value.indexWhere((s) => s.id == updatedSupplier.id);
    if (index != -1) {
      final newList = List<Supplier>.from(value);
      newList[index] = updatedSupplier;
      value = newList;
      supplierRepository.update(updatedSupplier);
    }
  }
}

final SupplierService supplierService = SupplierService();

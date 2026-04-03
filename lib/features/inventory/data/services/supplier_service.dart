import 'package:flutter/widgets.dart';
import 'package:reebaplus_pos/features/inventory/data/models/supplier.dart';
import 'package:reebaplus_pos/features/inventory/data/models/crate_group.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';

class SupplierService extends ValueNotifier<List<Supplier>> {
  SupplierService() : super([]) {
    _init();
  }

  void _init() {
    database.catalogDao.watchAllSupplierDatas().listen((dataList) {
      value = dataList.map(_fromDb).toList();
    });
  }

  static Supplier _fromDb(SupplierData d) {
    final crateGroup = CrateGroup.values.firstWhere(
      (cg) => cg.label == d.crateGroupName,
      orElse: () => CrateGroup.nbPlc,
    );
    return Supplier(
      id: d.id.toString(),
      name: d.name,
      crateGroup: crateGroup,
      contactDetails: [d.phone, d.email, d.address]
          .where((s) => s != null && s.isNotEmpty)
          .join(', '),
    );
  }

  List<Supplier> getAll() => List.unmodifiable(value);

  Supplier? getById(String id) {
    try {
      return value.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    // stub — no DB write
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

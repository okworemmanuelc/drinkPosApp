import 'package:flutter/material.dart';

import '../../features/customers/data/models/customer.dart';

class CartService extends ValueNotifier<List<Map<String, dynamic>>> {
  final ValueNotifier<Customer?> activeCustomer = ValueNotifier<Customer?>(null);

  CartService() : super([]);

  void setActiveCustomer(Customer? customer) {
    activeCustomer.value = customer;
  }

  void addItem(Map<String, dynamic> product, {double qty = 1.0}) {
    final index = value.indexWhere((item) => item['name'] == product['name']);
    if (index != -1) {
      final updatedList = List<Map<String, dynamic>>.from(value);
      updatedList[index]['qty'] += qty;
      value = updatedList;
    } else {
      value = [
        ...value,
        {
          'name': product['name'],
          'subtitle': product['subtitle'],
          'price': product['price'],
          'qty': qty,
          'icon': product['icon'],
          'color': product['color'],
          'category': product['category'],
        },
      ];
    }
  }

  void updateQty(String productName, double newQty) {
    final index = value.indexWhere((item) => item['name'] == productName);
    if (index != -1) {
      final updatedList = List<Map<String, dynamic>>.from(value);
      if (newQty <= 0) {
        updatedList.removeAt(index);
      } else {
        updatedList[index]['qty'] = newQty;
      }
      value = updatedList;
    }
  }

  void removeItem(String productName) {
    value = value.where((item) => item['name'] != productName).toList();
  }

  void clear() {
    value = [];
  }

  double get totalItems =>
      value.fold(0, (sum, item) => sum + (item['qty'] as double));

  int get itemCount => value.length;

  double get subtotal => value.fold(
    0,
    (sum, item) =>
        sum +
        ((item['price'] as num).toDouble() * (item['qty'] as num).toDouble()),
  );
}

final cartService = CartService();

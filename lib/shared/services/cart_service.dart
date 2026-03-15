import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../features/customers/data/models/customer.dart';
import '../../core/database/app_database.dart';

class CartService extends ValueNotifier<List<Map<String, dynamic>>> {
  final ValueNotifier<Customer?> activeCustomer = ValueNotifier<Customer?>(null);

  CartService() : super([]);

  void setActiveCustomer(Customer? customer) {
    activeCustomer.value = customer;
  }

  void addItem(dynamic product, {double qty = 1.0}) {
    // Handling both legacy Map (Quick Sale) and new ProductData class
    final String name = product is ProductData ? product.name : product['name'];
    final int? id = product is ProductData ? product.id : null;
    
    final index = value.indexWhere((item) => item['id'] == id && item['name'] == name);
    
    if (index != -1) {
      final updatedList = List<Map<String, dynamic>>.from(value);
      updatedList[index]['qty'] += qty;
      value = updatedList;
    } else {
      final Map<String, dynamic> itemToAdd = {
        'id': id,
        'name': name,
        'subtitle': product is ProductData ? product.subtitle : product['subtitle'],
        'price': product is ProductData ? product.sellingPriceKobo / 100.0 : product['price'], // Convert kobo to double for UI
        'qty': qty,
        'icon': product is ProductData ? (product.iconCodePoint ?? FontAwesomeIcons.box.codePoint) : product['icon'],
        'color': product is ProductData ? product.colorHex : product['color'],
        'category': product is ProductData ? product.categoryId : product['category'], // Note: category is Int in DB
        'crateGroupId': product is ProductData ? product.crateGroupId : product['crateGroupId'],
        'crateGroupName': product is ProductData ? null : product['crateGroupName'],
        'needsEmptyCrate': product is ProductData ? (product.crateGroupId != null) : product['needsEmptyCrate'],
      };

      value = [...value, itemToAdd];
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

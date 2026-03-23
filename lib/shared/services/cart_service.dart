import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../features/customers/data/models/customer.dart';
import '../../core/database/app_database.dart';
import 'auth_service.dart';

class CartService extends ValueNotifier<List<Map<String, dynamic>>> {
  final ValueNotifier<Customer?> activeCustomer = ValueNotifier<Customer?>(null);

  // Per-user cart storage: userId → cart items
  final Map<int, List<Map<String, dynamic>>> _userCarts = {};
  // Per-user active customer: userId → customer
  final Map<int, Customer?> _userCustomers = {};

  CartService() : super([]) {
    // Swap to the new user's cart whenever login/logout happens
    authService.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    final uid = _uid;
    value = List.from(_userCarts[uid] ?? []);
    activeCustomer.value = _userCustomers[uid];
  }

  /// The current user's ID. Falls back to 0 (anonymous) when nobody is logged in.
  int get _uid => authService.currentUser?.id ?? 0;

  void setActiveCustomer(Customer? customer) {
    _userCustomers[_uid] = customer;
    activeCustomer.value = customer;
  }

  void addItem(dynamic product, {double qty = 1.0}) {
    // Handling both legacy Map (Quick Sale) and new ProductData class
    final String name = product is ProductData ? product.name : product['name'];
    final int? id = product is ProductData ? product.id : null;

    final current = List<Map<String, dynamic>>.from(_userCarts[_uid] ?? []);
    final index = current.indexWhere((item) => item['id'] == id && item['name'] == name);

    if (index != -1) {
      current[index]['qty'] += qty;
    } else {
      current.add({
        'id': id,
        'name': name,
        'subtitle': product is ProductData ? product.subtitle : product['subtitle'],
        'price': product is ProductData
            ? (product.sellingPriceKobo > 0
                ? product.sellingPriceKobo
                : product.retailPriceKobo) /
                100.0
            : product['price'],
        'qty': qty,
        'icon': product is ProductData ? (product.iconCodePoint ?? FontAwesomeIcons.box.codePoint) : product['icon'],
        'color': product is ProductData ? product.colorHex : product['color'],
        'category': product is ProductData ? product.categoryId : product['category'],
        'crateGroupId': product is ProductData ? product.crateGroupId : product['crateGroupId'],
        'crateGroupName': product is ProductData ? null : product['crateGroupName'],
        'emptyCrateValueKobo': product is ProductData ? product.emptyCrateValueKobo : (product['emptyCrateValueKobo'] ?? 0),
        'manufacturerId': product is ProductData ? product.manufacturerId : product['manufacturerId'],
        'buyingPriceKobo': product is ProductData ? product.buyingPriceKobo : (product['buyingPriceKobo'] ?? 0),
      });
    }

    _userCarts[_uid] = current;
    value = List.from(current);
  }

  void updateQty(String productName, double newQty) {
    final current = List<Map<String, dynamic>>.from(_userCarts[_uid] ?? []);
    final index = current.indexWhere((item) => item['name'] == productName);
    if (index != -1) {
      if (newQty <= 0) {
        current.removeAt(index);
      } else {
        current[index]['qty'] = newQty;
      }
      _userCarts[_uid] = current;
      value = List.from(current);
    }
  }

  void removeItem(String productName) {
    final current = List<Map<String, dynamic>>.from(_userCarts[_uid] ?? [])
        .where((item) => item['name'] != productName)
        .toList();
    _userCarts[_uid] = current;
    value = List.from(current);
  }

  void clear() {
    _userCarts[_uid] = [];
    _userCustomers[_uid] = null;
    value = [];
    activeCustomer.value = null;
  }

  /// Refreshes product fields (name, price, emptyCrateValueKobo) across ALL
  /// user carts for the given product ID. Does not touch qty.
  /// Call this immediately after saving a product update to the DB.
  void refreshProduct({
    required int productId,
    required String name,
    required double price,
    required int emptyCrateValueKobo,
  }) {
    bool anyChanged = false;
    for (final uid in _userCarts.keys) {
      final cart = _userCarts[uid]!;
      for (int i = 0; i < cart.length; i++) {
        if (cart[i]['id'] == productId) {
          cart[i] = Map<String, dynamic>.from(cart[i])
            ..['name'] = name
            ..['price'] = price
            ..['emptyCrateValueKobo'] = emptyCrateValueKobo;
          anyChanged = true;
        }
      }
    }
    if (anyChanged) {
      value = List.from(_userCarts[_uid] ?? []);
    }
  }

  void loadCart(List<Map<String, dynamic>> items, Customer? customer) {
    _userCustomers[_uid] = customer;
    _userCarts[_uid] = List.from(items);
    activeCustomer.value = customer;
    value = List.from(items);
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

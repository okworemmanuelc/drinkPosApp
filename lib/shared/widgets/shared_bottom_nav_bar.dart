import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../shared/models/order.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/navigation_service.dart';
import '../../shared/services/order_service.dart';

/// A bottom navigation bar for detail screens pushed on top of MainLayout.
///
/// Tapping a tab pops all routes back to the root first, then switches tabs,
/// so the user always lands on the main layout rather than trying to switch
/// tabs while a detail screen is still open.
class SharedBottomNavBar extends StatefulWidget {
  const SharedBottomNavBar({super.key});

  @override
  State<SharedBottomNavBar> createState() => _SharedBottomNavBarState();
}

class _SharedBottomNavBarState extends State<SharedBottomNavBar> {
  int _pendingOrderCount = 0;
  StreamSubscription<List<Order>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = orderService.watchPendingOrders().listen((orders) {
      if (mounted) setState(() => _pendingOrderCount = orders.length);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onTap(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    switch (index) {
      case 0:
        navigationService.setIndex(0);
        break;
      case 1:
        navigationService.setIndex(1);
        break;
      case 2:
        navigationService.setIndex(2);
        break;
      case 3:
        navigationService.setIndex(3);
        break;
      case 4:
        navigationService.setIndex(9);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: navigationService.currentIndex,
      builder: (context, currentIndex, _) {
        final navIndex = currentIndex == 0
            ? 0
            : (currentIndex == 1
                ? 1
                : (currentIndex == 2
                    ? 2
                    : (currentIndex == 3
                        ? 3
                        : (currentIndex == 9 ? 4 : 0))));

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: cartService,
          builder: (context, cart, _) => BottomNavigationBar(
            currentIndex: navIndex,
            onTap: (index) => _onTap(context, index),
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale_outlined),
                activeIcon: Icon(Icons.point_of_sale),
                label: 'POS',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Stock',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text(_pendingOrderCount.toString()),
                  isLabelVisible: _pendingOrderCount > 0,
                  backgroundColor: danger,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                activeIcon: Badge(
                  label: Text(_pendingOrderCount.toString()),
                  isLabelVisible: _pendingOrderCount > 0,
                  backgroundColor: danger,
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text(cart.length.toString()),
                  isLabelVisible: cart.isNotEmpty,
                  backgroundColor: danger,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                activeIcon: Badge(
                  label: Text(cart.length.toString()),
                  isLabelVisible: cart.isNotEmpty,
                  backgroundColor: danger,
                  child: const Icon(Icons.shopping_cart),
                ),
                label: 'Cart',
              ),
            ],
          ),
        );
      },
    );
  }
}

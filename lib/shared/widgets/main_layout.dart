import 'dart:async';

import 'package:flutter/material.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/pos/screens/pos_home_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/warehouse/screens/warehouse_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/pos/screens/cart_screen.dart';
import '../../features/deliveries/screens/deliveries_screen.dart';
import '../../shared/widgets/activity_log_screen.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/navigation_service.dart';
import '../../shared/services/order_service.dart';
import '../../shared/models/order.dart';
import '../../core/theme/colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static void _voidOnCustomerChanged(dynamic _) {}

  // Persistent pending-orders count — subscribed once, never recreated.
  int _pendingOrderCount = 0;
  StreamSubscription<List<Order>>? _pendingOrdersSub;

  @override
  void initState() {
    super.initState();
    _pendingOrdersSub = orderService.watchPendingOrders().listen((orders) {
      if (mounted) setState(() => _pendingOrderCount = orders.length);
    });
  }

  @override
  void dispose() {
    _pendingOrdersSub?.cancel();
    super.dispose();
  }

  /// Returns the widget for the given navigation index.
  /// Only the ACTIVE screen is in the widget tree at any time — no IndexedStack
  /// keeping all 12 screens alive simultaneously.
  Widget _buildScreen(int index, List<Map<String, dynamic>> cart) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const PosHomeScreen();
      case 2:
        return const InventoryScreen();
      case 3:
        return const OrdersScreen();
      case 4:
        return const CustomersScreen();
      case 5:
        return const PaymentsScreen();
      case 6:
        return const ExpensesScreen();
      case 7:
        return const WarehouseScreen();
      case 8:
        return const StaffScreen();
      case 9:
        return CartScreen(
          cart: cart,
          crateDeposit: 0.0,
          onCustomerChanged: _voidOnCustomerChanged,
        );
      case 10:
        return const DeliveriesScreen();
      case 11:
        return const ActivityLogScreen();
      default:
        return const PosHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: navigationService.currentIndex,
      builder: (context, currentIndex, _) {
        return PopScope(
          canPop: currentIndex == 1,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (currentIndex != 1) navigationService.setIndex(1);
          },
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: cartService,
            builder: (context, cart, _) => Scaffold(
              // Optimize performance by keeping primary screens in an IndexedStack.
              // This preserves state (scroll position, form data) and makes switching instant.
              body: () {
                final primaryIndices = [0, 1, 2, 3, 9];
                final stackIndex = primaryIndices.indexOf(currentIndex);

                if (stackIndex != -1) {
                  return IndexedStack(
                    index: stackIndex,
                    children: [
                      const DashboardScreen(),
                      const PosHomeScreen(),
                      const InventoryScreen(),
                      const OrdersScreen(),
                      CartScreen(
                        cart: cart,
                        crateDeposit: 0.0,
                        onCustomerChanged: _voidOnCustomerChanged,
                      ),
                    ],
                  );
                }

                // For secondary screens (Customers, Payments, etc.), build dynamically to save memory.
                return KeyedSubtree(
                  key: ValueKey<int>(currentIndex),
                  child: _buildScreen(currentIndex, cart),
                );
              }(),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: currentIndex == 0
                    ? 0
                    : (currentIndex == 1
                        ? 1
                        : (currentIndex == 2
                            ? 2
                            : (currentIndex == 3
                                ? 3
                                : (currentIndex == 9 ? 4 : 0)))),
                onTap: (index) {
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
                },
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
            ),
          ),
        );
      },
    );
  }
}

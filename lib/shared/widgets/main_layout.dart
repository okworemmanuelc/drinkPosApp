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

// ── Lazy IndexedStack ──────────────────────────────────────────────────────
// Only builds a child widget the very first time that tab is visited.
// After that first build the child is kept alive forever (identical to a
// normal IndexedStack), preserving scroll position and stream state.
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _LazyIndexedStack({required this.index, required this.children});

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    // Mark only the first visible tab as activated; everything else is a stub.
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // First time the user visits a tab: activate it so the real widget builds.
    if (!_activated[widget.index]) {
      setState(() => _activated[widget.index] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        // Unvisited tabs get a bare SizedBox so nothing is built yet.
        return _activated[i] ? widget.children[i] : const SizedBox.shrink();
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
              // IndexedStack keeps all screens alive for state preservation.
              // RepaintBoundary isolates each screen's painting so Flutter does
              // not repaint inactive screens when a detail route is pushed.
              body: _LazyIndexedStack(
                index: currentIndex,
                children: [
                  const RepaintBoundary(child: DashboardScreen()),  // 0
                  const RepaintBoundary(child: PosHomeScreen()),    // 1
                  const RepaintBoundary(child: InventoryScreen()),  // 2
                  const RepaintBoundary(child: OrdersScreen()),     // 3
                  const RepaintBoundary(child: CustomersScreen()),  // 4
                  const RepaintBoundary(child: PaymentsScreen()),   // 5
                  const RepaintBoundary(child: ExpensesScreen()),   // 6
                  const RepaintBoundary(child: WarehouseScreen()),  // 7
                  const RepaintBoundary(child: StaffScreen()),      // 8
                  RepaintBoundary(                                  // 9
                    child: CartScreen(
                      cart: cart,
                      crateDeposit: 0.0,
                      onCustomerChanged: _voidOnCustomerChanged,
                    ),
                  ),
                  const RepaintBoundary(child: DeliveriesScreen()),  // 10
                  const RepaintBoundary(child: ActivityLogScreen()), // 11
                ],
              ),
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

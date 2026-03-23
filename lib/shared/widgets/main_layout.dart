import 'dart:async';
import 'package:flutter/services.dart';

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
import '../../shared/services/auth_service.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/navigation_service.dart';
import '../../shared/services/order_service.dart';
import '../../shared/models/order.dart';
import '../../core/utils/notifications.dart';


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

  // Double-back-to-exit state
  DateTime? _lastBackPress;
  static const _exitThreshold = Duration(seconds: 2);

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
    final t = Theme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: navigationService.currentIndex,
      builder: (context, currentIndex, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            if (currentIndex != 1) {
              // Try to go back in history
              final popped = navigationService.popIndex();
              if (!popped) {
                // If no history, jump to POS
                navigationService.setIndex(1);
              }
            } else {
              // We are on POS screen (index 1) - handle double-back-to-exit
              final now = DateTime.now();
              if (_lastBackPress == null ||
                  now.difference(_lastBackPress!) > _exitThreshold) {
                _lastBackPress = now;
                AppNotification.showSuccess(context, 'Tapping back again closes the app');
              } else {
                // Consecutive tap within threshold - exit app
                SystemNavigator.pop();
              }
            }
          },
          child: Scaffold(
              // IndexedStack keeps all screens alive for state preservation.
              // RepaintBoundary isolates each screen's painting so Flutter does
              // not repaint inactive screens when a detail route is pushed.
              body: _LazyIndexedStack(
                index: currentIndex,
                children: const [
                  RepaintBoundary(child: DashboardScreen()),  // 0
                  RepaintBoundary(child: PosHomeScreen()),    // 1
                  RepaintBoundary(child: InventoryScreen()),  // 2
                  RepaintBoundary(child: OrdersScreen()),     // 3
                  RepaintBoundary(child: CustomersScreen()),  // 4
                  RepaintBoundary(child: PaymentsScreen()),   // 5
                  RepaintBoundary(child: ExpensesScreen()),   // 6
                  RepaintBoundary(child: WarehouseScreen()),  // 7
                  RepaintBoundary(child: StaffScreen()),      // 8
                  RepaintBoundary(                            // 9
                    child: CartScreen(
                      cart: [],
                      crateDeposit: 0.0,
                      onCustomerChanged: _voidOnCustomerChanged,
                    ),
                  ),
                  RepaintBoundary(child: DeliveriesScreen()),  // 10
                  RepaintBoundary(child: ActivityLogScreen()), // 11
                ],
              ),
              bottomNavigationBar: ValueListenableBuilder(
                valueListenable: authService,
                builder: (context, user, _) {
                  final isCashier = (user?.roleTier ?? 1) < 4;
                  final iconColor = t.textTheme.bodySmall?.color ?? t.iconTheme.color!;

                  if (isCashier) {
                    // Cashier nav: POS(1), Stock(2), Orders(3), Cart(9)
                    final bool isNavTab = [1, 2, 3, 9].contains(currentIndex);
                    final int navIndex = currentIndex == 1
                        ? 0
                        : (currentIndex == 2
                            ? 1
                            : (currentIndex == 3 ? 2 : (currentIndex == 9 ? 3 : 0)));

                    return BottomNavigationBar(
                      currentIndex: navIndex,
                      selectedItemColor: isNavTab ? t.colorScheme.primary : iconColor,
                      unselectedItemColor: iconColor,
                      onTap: (index) {
                        switch (index) {
                          case 0: navigationService.setIndex(1); break;
                          case 1: navigationService.setIndex(2); break;
                          case 2: navigationService.setIndex(3); break;
                          case 3: navigationService.setIndex(9); break;
                        }
                      },
                      type: BottomNavigationBarType.fixed,
                      items: [
                        BottomNavigationBarItem(
                          icon: const Icon(Icons.point_of_sale_outlined),
                          activeIcon: Icon(isNavTab ? Icons.point_of_sale : Icons.point_of_sale_outlined),
                          label: 'POS',
                        ),
                        BottomNavigationBarItem(
                          icon: const Icon(Icons.inventory_2_outlined),
                          activeIcon: Icon(isNavTab ? Icons.inventory_2 : Icons.inventory_2_outlined),
                          label: 'Stock',
                        ),
                        BottomNavigationBarItem(
                          icon: Badge(
                            label: Text(_pendingOrderCount.toString()),
                            isLabelVisible: _pendingOrderCount > 0,
                            backgroundColor: t.colorScheme.error,
                            child: const Icon(Icons.receipt_long_outlined),
                          ),
                          activeIcon: Badge(
                            label: Text(_pendingOrderCount.toString()),
                            isLabelVisible: _pendingOrderCount > 0,
                            backgroundColor: t.colorScheme.error,
                            child: Icon(isNavTab ? Icons.receipt_long : Icons.receipt_long_outlined),
                          ),
                          label: 'Orders',
                        ),
                        BottomNavigationBarItem(
                          icon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: cartService,
                            builder: (_, cart, __) => Badge(
                              label: Text(cart.length.toString()),
                              isLabelVisible: cart.isNotEmpty,
                              backgroundColor: t.colorScheme.error,
                              child: const Icon(Icons.shopping_cart_outlined),
                            ),
                          ),
                          activeIcon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: cartService,
                            builder: (_, cart, __) => Badge(
                              label: Text(cart.length.toString()),
                              isLabelVisible: cart.isNotEmpty,
                              backgroundColor: t.colorScheme.error,
                              child: Icon(isNavTab ? Icons.shopping_cart : Icons.shopping_cart_outlined),
                            ),
                          ),
                          label: 'Cart',
                        ),
                      ],
                    );
                  }

                  // Manager / CEO nav: Home(0), POS(1), Stock(2), Orders(3), Cart(9)
                  final bool isNavTab = [0, 1, 2, 3, 9].contains(currentIndex);
                  final int navIndex = currentIndex == 0
                      ? 0
                      : (currentIndex == 1
                          ? 1
                          : (currentIndex == 2
                              ? 2
                              : (currentIndex == 3
                                  ? 3
                                  : (currentIndex == 9 ? 4 : 0))));

                  return BottomNavigationBar(
                    currentIndex: navIndex,
                    selectedItemColor: isNavTab ? t.colorScheme.primary : iconColor,
                    unselectedItemColor: iconColor,
                    onTap: (index) {
                      switch (index) {
                        case 0: navigationService.setIndex(0); break;
                        case 1: navigationService.setIndex(1); break;
                        case 2: navigationService.setIndex(2); break;
                        case 3: navigationService.setIndex(3); break;
                        case 4: navigationService.setIndex(9); break;
                      }
                    },
                    type: BottomNavigationBarType.fixed,
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(isNavTab ? Icons.dashboard : Icons.dashboard_outlined),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.point_of_sale_outlined),
                        activeIcon: Icon(isNavTab ? Icons.point_of_sale : Icons.point_of_sale_outlined),
                        label: 'POS',
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.inventory_2_outlined),
                        activeIcon: Icon(isNavTab ? Icons.inventory_2 : Icons.inventory_2_outlined),
                        label: 'Stock',
                      ),
                      BottomNavigationBarItem(
                        icon: Badge(
                          label: Text(_pendingOrderCount.toString()),
                          isLabelVisible: _pendingOrderCount > 0,
                          backgroundColor: t.colorScheme.error,
                          child: const Icon(Icons.receipt_long_outlined),
                        ),
                        activeIcon: Badge(
                          label: Text(_pendingOrderCount.toString()),
                          isLabelVisible: _pendingOrderCount > 0,
                          backgroundColor: t.colorScheme.error,
                          child: Icon(isNavTab ? Icons.receipt_long : Icons.receipt_long_outlined),
                        ),
                        label: 'Orders',
                      ),
                      BottomNavigationBarItem(
                        icon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: cartService,
                          builder: (_, cart, __) => Badge(
                            label: Text(cart.length.toString()),
                            isLabelVisible: cart.isNotEmpty,
                            backgroundColor: t.colorScheme.error,
                            child: const Icon(Icons.shopping_cart_outlined),
                          ),
                        ),
                        activeIcon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: cartService,
                          builder: (_, cart, __) => Badge(
                            label: Text(cart.length.toString()),
                            isLabelVisible: cart.isNotEmpty,
                            backgroundColor: t.colorScheme.error,
                            child: Icon(isNavTab ? Icons.shopping_cart : Icons.shopping_cart_outlined),
                          ),
                        ),
                        label: 'Cart',
                      ),
                    ],
                  );
                },
              ),
            ),
        );
      },
    );
  }
}

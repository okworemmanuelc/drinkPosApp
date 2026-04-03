import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:reebaplus_pos/features/dashboard/screens/dashboard_screen.dart';
import 'package:reebaplus_pos/features/pos/screens/pos_home_screen.dart';
import 'package:reebaplus_pos/features/inventory/screens/inventory_screen.dart';
import 'package:reebaplus_pos/features/orders/screens/orders_screen.dart';
import 'package:reebaplus_pos/features/customers/screens/customers_screen.dart';
import 'package:reebaplus_pos/features/payments/screens/payments_screen.dart';
import 'package:reebaplus_pos/features/expenses/screens/expenses_screen.dart';
import 'package:reebaplus_pos/features/warehouse/screens/warehouse_screen.dart';
import 'package:reebaplus_pos/features/staff/screens/staff_screen.dart';
import 'package:reebaplus_pos/features/pos/screens/cart_screen.dart';
import 'package:reebaplus_pos/features/deliveries/screens/deliveries_screen.dart';
import 'package:reebaplus_pos/shared/widgets/activity_log_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/services/cart_service.dart';
import 'package:reebaplus_pos/shared/services/navigation_service.dart';
import 'package:reebaplus_pos/shared/services/order_service.dart';
import 'package:reebaplus_pos/shared/models/order.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/widgets/tab_navigator.dart';

// The LazyIndexedStack has been replaced with the direct Offstage + Set approach
// requested for eliminating mount jank on cold start.

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static void _voidOnCustomerChanged(dynamic _) {}

  // 12 tabs = 12 Navigators
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    12,
    (_) => GlobalKey<NavigatorState>(),
  );

  // Track which tabs have ever been visited
  final Set<int> _initializedTabs = {};

  late final List<Widget Function()> _tabBuilders;

  // Persistent pending-orders count — subscribed once, never recreated.
  int _pendingOrderCount = 0;
  StreamSubscription<List<Order>>? _pendingOrdersSub;

  // Double-back-to-exit state
  DateTime? _lastBackPress;
  static const _exitThreshold = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _tabBuilders = [
      () => const DashboardScreen(), // 0
      () => const PosHomeScreen(), // 1
      () => const InventoryScreen(), // 2
      () => const OrdersScreen(), // 3
      () => const CustomersScreen(), // 4
      () => const PaymentsScreen(), // 5
      () => const ExpensesScreen(), // 6
      () => const WarehouseScreen(), // 7
      () => const StaffScreen(), // 8
      () => const CartScreen(
        cart: [],
        crateDeposit: 0.0,
        onCustomerChanged: _voidOnCustomerChanged,
      ), // 9
      () => const DeliveriesScreen(), // 10
      () => const ActivityLogScreen(), // 11
    ];

    // Only pre-load the landing tab
    _initializedTabs.add(navigationService.currentIndex.value);

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
        _initializedTabs.add(currentIndex); // mark as visited

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            final NavigatorState? currentNavigator =
                _navigatorKeys[currentIndex].currentState;

            // 1. If currently in a nested screen of the current tab, pop it first.
            if (currentNavigator != null && currentNavigator.canPop()) {
              currentNavigator.pop();
              return;
            }

            // 2. If not on POS screen (index 1), try to go back in main layout history.
            if (currentIndex != 1) {
              final popped = navigationService.popIndex();
              if (!popped) {
                // If no history, jump to POS
                navigationService.setIndex(1);
              }
            } else {
              // 3. We are on POS screen (index 1) - handle double-back-to-exit
              final now = DateTime.now();
              if (_lastBackPress == null ||
                  now.difference(_lastBackPress!) > _exitThreshold) {
                _lastBackPress = now;
                AppNotification.showSuccess(
                  context,
                  'Tapping back again closes the app',
                );
              } else {
                // Consecutive tap within threshold - exit app
                SystemNavigator.pop();
              }
            }
          },
          child: Scaffold(
            // Offstage keeps the widget alive and mounted for streams/scroll,
            // while `_initializedTabs` ensures exactly zero unused tabs are mounted initially.
            body: Stack(
              children: List.generate(12, (i) {
                if (!_initializedTabs.contains(i)) {
                  // Not yet visited — render nothing
                  return const SizedBox.shrink();
                }
                return Offstage(
                  offstage: i != currentIndex,
                  // TickerMode guarantees animations on offstage tabs don't tick
                  child: TickerMode(
                    enabled: i == currentIndex,
                    child: TabNavigator(
                      navigatorKey: _navigatorKeys[i],
                      rootScreen: _tabBuilders[i](),
                    ),
                  ),
                );
              }),
            ),
            bottomNavigationBar: ValueListenableBuilder(
              valueListenable: authService,
              builder: (context, user, _) {
                final isCashier = (user?.roleTier ?? 1) < 4;
                final iconColor =
                    t.textTheme.bodySmall?.color ?? t.iconTheme.color!;

                if (isCashier) {
                  // Cashier nav: POS(1), Stock(2), Orders(3), Cart(9)
                  final bool isNavTab = [1, 2, 3, 9].contains(currentIndex);
                  final int navIndex = currentIndex == 1
                      ? 0
                      : (currentIndex == 2
                            ? 1
                            : (currentIndex == 3
                                  ? 2
                                  : (currentIndex == 9 ? 3 : 0)));

                  return BottomNavigationBar(
                    currentIndex: navIndex,
                    selectedItemColor: isNavTab
                        ? t.colorScheme.primary
                        : iconColor,
                    unselectedItemColor: iconColor,
                    onTap: (index) {
                      int indexToSet = 1;
                      switch (index) {
                        case 0:
                          indexToSet = 1;
                          break;
                        case 1:
                          indexToSet = 2;
                          break;
                        case 2:
                          indexToSet = 3;
                          break;
                        case 3:
                          indexToSet = 9;
                          break;
                      }

                      if (currentIndex == indexToSet) {
                        // Tap current tab: pop all detail screens to root
                        _navigatorKeys[indexToSet].currentState?.popUntil(
                          (r) => r.isFirst,
                        );
                      } else {
                        navigationService.setIndex(indexToSet);
                      }
                    },
                    type: BottomNavigationBarType.fixed,
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.point_of_sale_outlined),
                        activeIcon: Icon(
                          isNavTab
                              ? Icons.point_of_sale
                              : Icons.point_of_sale_outlined,
                        ),
                        label: 'POS',
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.inventory_2_outlined),
                        activeIcon: Icon(
                          isNavTab
                              ? Icons.inventory_2
                              : Icons.inventory_2_outlined,
                        ),
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
                          child: Icon(
                            isNavTab
                                ? Icons.receipt_long
                                : Icons.receipt_long_outlined,
                          ),
                        ),
                        label: 'Orders',
                      ),
                      BottomNavigationBarItem(
                        icon:
                            ValueListenableBuilder<List<Map<String, dynamic>>>(
                              valueListenable: cartService,
                              builder: (_, cart, __) => Badge(
                                label: Text(cart.length.toString()),
                                isLabelVisible: cart.isNotEmpty,
                                backgroundColor: t.colorScheme.error,
                                child: const Icon(Icons.shopping_cart_outlined),
                              ),
                            ),
                        activeIcon:
                            ValueListenableBuilder<List<Map<String, dynamic>>>(
                              valueListenable: cartService,
                              builder: (_, cart, __) => Badge(
                                label: Text(cart.length.toString()),
                                isLabelVisible: cart.isNotEmpty,
                                backgroundColor: t.colorScheme.error,
                                child: Icon(
                                  isNavTab
                                      ? Icons.shopping_cart
                                      : Icons.shopping_cart_outlined,
                                ),
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
                  selectedItemColor: isNavTab
                      ? t.colorScheme.primary
                      : iconColor,
                  unselectedItemColor: iconColor,
                  onTap: (index) {
                    int indexToSet = 0;
                    switch (index) {
                      case 0:
                        indexToSet = 0;
                        break;
                      case 1:
                        indexToSet = 1;
                        break;
                      case 2:
                        indexToSet = 2;
                        break;
                      case 3:
                        indexToSet = 3;
                        break;
                      case 4:
                        indexToSet = 9;
                        break;
                    }

                    if (currentIndex == indexToSet) {
                      // Tap current tab: pop all detail screens to root
                      _navigatorKeys[indexToSet].currentState?.popUntil(
                        (r) => r.isFirst,
                      );
                    } else {
                      navigationService.setIndex(indexToSet);
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(
                        isNavTab ? Icons.dashboard : Icons.dashboard_outlined,
                      ),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.point_of_sale_outlined),
                      activeIcon: Icon(
                        isNavTab
                            ? Icons.point_of_sale
                            : Icons.point_of_sale_outlined,
                      ),
                      label: 'POS',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.inventory_2_outlined),
                      activeIcon: Icon(
                        isNavTab
                            ? Icons.inventory_2
                            : Icons.inventory_2_outlined,
                      ),
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
                        child: Icon(
                          isNavTab
                              ? Icons.receipt_long
                              : Icons.receipt_long_outlined,
                        ),
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
                      activeIcon:
                          ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: cartService,
                            builder: (_, cart, __) => Badge(
                              label: Text(cart.length.toString()),
                              isLabelVisible: cart.isNotEmpty,
                              backgroundColor: t.colorScheme.error,
                              child: Icon(
                                isNavTab
                                    ? Icons.shopping_cart
                                    : Icons.shopping_cart_outlined,
                              ),
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

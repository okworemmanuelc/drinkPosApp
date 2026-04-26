import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/shared/models/order.dart';
import 'package:reebaplus_pos/shared/widgets/tab_navigator.dart';

// The LazyIndexedStack has been replaced with the direct Offstage + Set approach
// requested for eliminating mount jank on cold start.

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver {
  static void _voidOnCustomerChanged(dynamic _) {}

  // 12 tabs = 12 Navigators
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    12,
    (_) => GlobalKey<NavigatorState>(),
  );

  // Track which tabs have ever been visited
  final Set<int> _initializedTabs = {};

  final List<Widget> _tabWidgets = [
    const DashboardScreen(), // 0
    const PosHomeScreen(), // 1
    const InventoryScreen(), // 2
    const OrdersScreen(), // 3
    const CustomersScreen(), // 4
    const PaymentsScreen(), // 5
    const ExpensesScreen(), // 6
    const WarehouseScreen(), // 7
    const StaffScreen(), // 8
    const CartScreen(
      cart: [],
      crateDeposit: 0.0,
      onCustomerChanged: _voidOnCustomerChanged,
    ), // 9
    const DeliveriesScreen(), // 10
    const ActivityLogScreen(), // 11
  ];

  // Persistent pending-orders count — subscribed once, never recreated.
  int _pendingOrderCount = 0;
  StreamSubscription<List<Order>>? _pendingOrdersSub;

  @override
  void initState() {
    super.initState();

    // Register BEFORE any Navigator so we get the back event first.
    WidgetsBinding.instance.addObserver(this);

    // Link shared keys
    final nav = ref.read(navigationProvider);
    nav.tabNavigatorKeys = _navigatorKeys;

    // Only pre-load the landing tab
    _initializedTabs.add(nav.currentIndex.value);

    _pendingOrdersSub = ref
        .read(orderServiceProvider)
        .watchPendingOrders()
        .listen((orders) {
          if (mounted) setState(() => _pendingOrderCount = orders.length);
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingOrdersSub?.cancel();
    super.dispose();
  }

  /// Intercepts the system back button at the highest level, before any
  /// nested Navigator (TabNavigator) can consume it.
  @override
  Future<bool> didPopRoute() async {
    final nav = ref.read(navigationProvider);
    final user = ref.read(authProvider).currentUser;
    nav.handleBackPress(context, user?.roleTier ?? 1);
    return true; // Always consume — we handle everything ourselves.
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final nav = ref.read(navigationProvider);

    return ValueListenableBuilder<int>(
      valueListenable: nav.currentIndex,
      builder: (context, currentIndex, _) {
        _initializedTabs.add(currentIndex); // mark as visited

        return Scaffold(
          key: nav.mainScaffoldKey,

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
                    rootScreen: _tabWidgets[i],
                  ),
                ),
              );
            }),
          ),
          bottomNavigationBar: ValueListenableBuilder(
            valueListenable: ref.read(authProvider),
            builder: (context, user, _) {
              final isCashier = (user?.roleTier ?? 1) < 4;
              final iconColor =
                  t.textTheme.bodySmall?.color ?? t.iconTheme.color!;

              if (isCashier) {
                // Cashier nav: Stock(2), POS(1), Orders(3), Cart(9)
                final bool isNavTab = [1, 2, 3, 9].contains(currentIndex);
                final int navIndex = currentIndex == 2
                    ? 0
                    : (currentIndex == 1
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
                    int indexToSet = 2;
                    switch (index) {
                      case 0:
                        indexToSet = 2;
                        break;
                      case 1:
                        indexToSet = 1;
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
                      nav.setIndex(indexToSet);
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  items: [
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
                      icon: const Icon(Icons.point_of_sale_outlined),
                      activeIcon: Icon(
                        isNavTab
                            ? Icons.point_of_sale
                            : Icons.point_of_sale_outlined,
                      ),
                      label: 'POS',
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
                        valueListenable: ref.read(cartProvider),
                        builder: (_, cart, __) => Badge(
                          label: Text(cart.length.toString()),
                          isLabelVisible: cart.isNotEmpty,
                          backgroundColor: t.colorScheme.error,
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                      ),
                      activeIcon:
                          ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: ref.read(cartProvider),
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

              // Manager / CEO nav: Home(0), Stock(2), POS(1), Orders(3), Cart(9)
              final bool isNavTab = [0, 1, 2, 3, 9].contains(currentIndex);
              final int navIndex = currentIndex == 0
                  ? 0
                  : (currentIndex == 2
                        ? 1
                        : (currentIndex == 1
                              ? 2
                              : (currentIndex == 3
                                    ? 3
                                    : (currentIndex == 9 ? 4 : 0))));

              return BottomNavigationBar(
                currentIndex: navIndex,
                selectedItemColor: isNavTab ? t.colorScheme.primary : iconColor,
                unselectedItemColor: iconColor,
                onTap: (index) {
                  int indexToSet = 0;
                  switch (index) {
                    case 0:
                      indexToSet = 0;
                      break;
                    case 1:
                      indexToSet = 2;
                      break;
                    case 2:
                      indexToSet = 1;
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
                    nav.setIndex(indexToSet);
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
                    icon: const Icon(Icons.inventory_2_outlined),
                    activeIcon: Icon(
                      isNavTab ? Icons.inventory_2 : Icons.inventory_2_outlined,
                    ),
                    label: 'Stock',
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
                      valueListenable: ref.read(cartProvider),
                      builder: (_, cart, __) => Badge(
                        label: Text(cart.length.toString()),
                        isLabelVisible: cart.isNotEmpty,
                        backgroundColor: t.colorScheme.error,
                        child: const Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                    activeIcon:
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: ref.read(cartProvider),
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
        );
      },
    );
  }
}

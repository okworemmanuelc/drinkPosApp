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

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(), // 0
      const PosHomeScreen(), // 1
      const InventoryScreen(), // 2
      const OrdersScreen(), // 3
      const CustomersScreen(), // 4
      const PaymentsScreen(), // 5 (Supplier Accounts)
      const ExpensesScreen(), // 6
      const WarehouseScreen(), // 7
      const StaffScreen(), // 8
      ValueListenableBuilder<List<Map<String, dynamic>>>(
        // 9
        valueListenable: cartService,
        builder: (context, cart, _) => CartScreen(
          cart: cart,
          crateDeposit: 0.0,
          onCustomerChanged: _voidOnCustomerChanged,
        ),
      ),
      const DeliveriesScreen(), // 10
      const ActivityLogScreen(), // 11
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: navigationService.currentIndex,
      builder: (context, currentIndex, _) {
        return PopScope(
          canPop: currentIndex == 1, // POS is at index 1 now
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (currentIndex != 1) {
              navigationService.setIndex(1); // Return to POS
            }
          },
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: IndexedStack(
                index: currentIndex,
                children: _screens,
              ),
            ),
            bottomNavigationBar:
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: cartService,
                  builder: (context, cart, _) => BottomNavigationBar(
                    currentIndex: (currentIndex >= 1 && currentIndex <= 3)
                        ? (currentIndex - 1)
                        : (currentIndex == 9 ? 3 : 0),
                    onTap: (index) {
                      if (index == 3) {
                        navigationService.setIndex(9); // Cart
                      } else {
                        navigationService.setIndex(
                          index + 1,
                        ); // POS, Inventory, Orders
                      }
                    },
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor:
                        (currentIndex >= 1 && currentIndex <= 3) ||
                            currentIndex == 9
                        ? blueMain
                        : Colors.grey,
                    unselectedItemColor: Colors.grey,
                    showUnselectedLabels: true,
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.point_of_sale),
                        label: 'POS',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.inventory_2),
                        label: 'Inventory',
                      ),
                      BottomNavigationBarItem(
                        icon: ValueListenableBuilder<List<Order>>(
                          valueListenable: orderService,
                          builder: (context, orders, _) {
                            final pendingCount =
                                orders.where((o) => o.status == 'pending').length;
                            return Badge(
                              label: Text(pendingCount.toString()),
                              isLabelVisible: pendingCount > 0,
                              backgroundColor: danger,
                              child: const Icon(Icons.receipt_long),
                            );
                          },
                        ),
                        label: 'Orders',
                      ),
                      BottomNavigationBarItem(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Badge(
                            key: ValueKey<int>(cart.length),
                            label: Text(cart.length.toString()),
                            isLabelVisible: cart.isNotEmpty,
                            backgroundColor: danger,
                            child: const Icon(Icons.shopping_cart),
                          ),
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

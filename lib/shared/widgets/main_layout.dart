import 'package:flutter/material.dart';
import '../../features/pos/screens/pos_home_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/pos/screens/cart_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/deliveries/screens/deliveries_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../shared/widgets/activity_log_screen.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/navigation_service.dart';
import '../../core/theme/colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static void _voidOnCustomerChanged(dynamic _) {}

  // The actual screens for the bottom nav
  List<Widget> get _screens => [
    const PosHomeScreen(), // 0
    const InventoryScreen(), // 1
    const OrdersScreen(), // 2
    ValueListenableBuilder<List<Map<String, dynamic>>>(
      // 3
      valueListenable: cartService,
      builder: (context, cart, _) => CartScreen(
        cart: cart,
        crateDeposit: 0.0,
        onCustomerChanged: _voidOnCustomerChanged,
      ),
    ),
    const PaymentsScreen(), // 4
    const DeliveriesScreen(), // 5
    const ExpensesScreen(), // 6
    const CustomersScreen(), // 7
    const ActivityLogScreen(), // 8
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: navigationService.currentIndex,
      builder: (context, currentIndex, _) {
        return Scaffold(
          body: IndexedStack(index: currentIndex, children: _screens),
          bottomNavigationBar:
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: cartService,
                builder: (context, cart, _) => BottomNavigationBar(
                  currentIndex: (currentIndex < 4) ? currentIndex : 0,
                  onTap: (index) {
                    navigationService.setIndex(index);
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: (currentIndex < 4)
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
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long),
                      label: 'Orders',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
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
        );
      },
    );
  }
}

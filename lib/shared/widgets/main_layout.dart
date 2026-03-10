import 'package:flutter/material.dart';
import '../../features/pos/screens/pos_home_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/pos/screens/cart_screen.dart';
import '../../shared/services/cart_service.dart';
import '../../core/theme/colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  static void _voidOnCustomerChanged(dynamic _) {}

  // The actual screens for the bottom nav
  List<Widget> get _screens => [
    const PosHomeScreen(),
    const InventoryScreen(),
    const OrdersScreen(),
    ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: cartService,
      builder: (context, cart, _) => CartScreen(
        cart: cart,
        crateDeposit: 0.0,
        onCustomerChanged: _voidOnCustomerChanged,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: cartService,
        builder: (context, cart, _) => BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: blueMain,
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
  }
}

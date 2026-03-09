import 'package:flutter/material.dart';
import '../../features/pos/screens/pos_home_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/pos/screens/cart_screen.dart';
import 'app_drawer.dart';
import '../../core/theme/colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  static void _voidOnCustomerChanged(dynamic _) {}

  // The actual screens for the bottom nav
  final List<Widget> _screens = [
    const PosHomeScreen(),
    const InventoryScreen(),
    const OrdersScreen(),
    const CartScreen(
      cart: [],
      crateDeposit: 0.0,
      onCustomerChanged: _voidOnCustomerChanged,
    ), // Cart will be managed by a global state or proxy soon
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(
        activeRoute: 'pos',
      ), // Will update activeRoute dynamically later
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Right swipe detection
          if (details.primaryVelocity! > 300) {
            _scaffoldKey.currentState?.openDrawer();
          }
        },
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}

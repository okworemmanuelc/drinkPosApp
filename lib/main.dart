import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'shared/widgets/app_drawer.dart';
import 'shared/widgets/activity_log_screen.dart';
import 'features/customers/screens/customers_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/payments/screens/payments_screen.dart';
import 'features/deliveries/screens/deliveries_screen.dart';
import 'features/expenses/screens/expenses_screen.dart';
import 'shared/widgets/main_layout.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Wire up the real InventoryScreen into the drawer at startup.
  // This breaks the circular import: AppDrawer never imports InventoryScreen.
  registerInventoryScreen(() => const InventoryScreen());

  // Wire up ActivityLogScreen to AppDrawer proxy
  registerActivityLogScreen(() => const ActivityLogScreen());

  // Wire up CustomersScreen to AppDrawer proxy
  registerCustomersScreen(() => const CustomersScreen());

  // Wire up OrdersScreen to AppDrawer proxy
  registerOrdersScreen(() => const OrdersScreen());

  // Wire up PaymentsScreen to AppDrawer proxy
  registerPaymentsScreen(() => const PaymentsScreen());

  // Wire up DeliveriesScreen to AppDrawer proxy
  registerDeliveriesScreen(() => const DeliveriesScreen());

  // Wire up ExpensesScreen to AppDrawer proxy
  registerExpensesScreen(() => const ExpensesScreen());

  runApp(const BrewFlowApp());
}

class BrewFlowApp extends StatelessWidget {
  const BrewFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'BrewFlow POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const MainLayout(),
      ),
    );
  }
}

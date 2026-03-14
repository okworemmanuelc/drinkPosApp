import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/database/database_helper.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

import 'features/auth/screens/onboarding_screen.dart';

// Services
import 'shared/services/activity_log_service.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/order_service.dart';
import 'features/customers/data/services/customer_service.dart';
import 'features/expenses/data/services/expense_service.dart';
import 'features/inventory/data/services/supplier_service.dart';
import 'features/payments/data/services/payment_service.dart';
import 'features/deliveries/data/services/delivery_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Load .env (Supabase credentials)
  await dotenv.load(fileName: '.env');

  // Initialize local SQLite database
  await DatabaseHelper.instance.init();

  // Initialize Supabase (offline-safe — skips if .env is empty)
  await SupabaseConfig.init();

  // Load all services from local DB
  await Future.wait([
    activityLogService.init(),
    notificationService.init(),
    customerService.init(),
    orderService.init(),
    expenseService.init(),
    supplierService.init(),
    paymentService.init(),
    deliveryService.init(),
  ]);

  // Start background sync listener (no-op if Supabase not configured)
  SyncService.instance.startListening();

  // Trigger initial sync if online
  SyncService.instance.sync();

  runApp(const OnafiaPosApp());
}

class OnafiaPosApp extends StatelessWidget {
  const OnafiaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'Onafia POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const OnboardingScreen(),
      ),
    );
  }
}

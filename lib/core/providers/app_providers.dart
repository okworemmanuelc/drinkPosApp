/// Riverpod providers — all services constructed via ref.read().
///
/// Only `database` and `themeController` remain as globals because they
/// must be initialised before `runApp()`. Everything else is constructed
/// here with proper dependency injection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/services/biometric_service.dart';
import 'package:reebaplus_pos/core/theme/theme_notifier.dart';
import 'package:reebaplus_pos/features/customers/data/models/customer.dart';
import 'package:reebaplus_pos/features/customers/data/services/customer_service.dart';
import 'package:reebaplus_pos/features/deliveries/data/models/delivery_receipt.dart';
import 'package:reebaplus_pos/features/deliveries/data/services/delivery_service.dart';
import 'package:reebaplus_pos/features/expenses/data/services/expense_service.dart';
import 'package:reebaplus_pos/features/inventory/data/services/supplier_service.dart';
import 'package:reebaplus_pos/features/payments/data/services/payment_service.dart';
import 'package:reebaplus_pos/shared/services/activity_log_service.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/services/secure_storage_service.dart';
import 'package:reebaplus_pos/shared/services/cart_service.dart';
import 'package:reebaplus_pos/shared/services/navigation_service.dart';
import 'package:reebaplus_pos/shared/services/notification_service.dart';
import 'package:reebaplus_pos/shared/services/order_service.dart';
import 'package:reebaplus_pos/shared/services/printer_service.dart';
import 'package:reebaplus_pos/shared/services/reorder_alert_service.dart';
import 'package:reebaplus_pos/core/services/supabase_sync_service.dart';

// ── Database (global — initialised before runApp) ──────────────────────────
final databaseProvider = Provider<AppDatabase>((_) => database);

// ── Navigation ─────────────────────────────────────────────────────────────
final navigationProvider = Provider<NavigationService>((ref) {
  return NavigationService();
});
final currentIndexProvider = ChangeNotifierProvider<ValueNotifier<int>>((ref) {
  return ref.watch(navigationProvider).currentIndex;
});
final lockedWarehouseProvider =
    ChangeNotifierProvider<ValueNotifier<int?>>((ref) {
  return ref.watch(navigationProvider).lockedWarehouseId;
});

// ── Secure Storage ─────────────────────────────────────────────────────────
final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

// ── Auth ────────────────────────────────────────────────────────────────────
final authProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService(
    ref.read(databaseProvider),
    ref.read(navigationProvider),
    ref.read(secureStorageProvider),
    ref.read(supabaseSyncServiceProvider),
  );
});
final deviceUserIdProvider =
    ChangeNotifierProvider<ValueNotifier<int?>>((ref) {
  return ref.watch(authProvider).deviceUserIdNotifier;
});

// ── Theme (global — initialised before runApp) ─────────────────────────────
final themeProvider =
    ChangeNotifierProvider<ThemeController>((_) => themeController);

// ── Cart ────────────────────────────────────────────────────────────────────
final cartProvider = ChangeNotifierProvider<CartService>((ref) {
  return CartService(ref.read(authProvider));
});
final activeCustomerProvider =
    ChangeNotifierProvider<ValueNotifier<Customer?>>((ref) {
  return ref.watch(cartProvider).activeCustomer;
});

// ── Notification ────────────────────────────────────────────────────────────
final notificationProvider =
    ChangeNotifierProvider<NotificationService>((ref) {
  return NotificationService(ref.read(databaseProvider));
});

// ── Activity Log ────────────────────────────────────────────────────────────
final activityLogProvider =
    ChangeNotifierProvider<ActivityLogService>((ref) {
  return ActivityLogService(
      ref.read(databaseProvider), ref.read(authProvider));
});

// ── Order ───────────────────────────────────────────────────────────────────
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.read(databaseProvider));
});

// ── Customer ────────────────────────────────────────────────────────────────
final customerServiceProvider =
    ChangeNotifierProvider<CustomerService>((ref) {
  return CustomerService(
      ref.read(databaseProvider), ref.read(activityLogProvider));
});

// ── Supplier ────────────────────────────────────────────────────────────────
final supplierServiceProvider =
    ChangeNotifierProvider<SupplierService>((ref) {
  return SupplierService(ref.read(databaseProvider));
});

// ── Delivery ────────────────────────────────────────────────────────────────
final deliveryServiceProvider =
    ChangeNotifierProvider<DeliveryService>((ref) {
  return DeliveryService(ref.read(notificationProvider));
});
final deliveryReceiptServiceProvider =
    ChangeNotifierProvider<DeliveryReceiptService>((ref) {
  return DeliveryReceiptService();
});

// ── Expense ─────────────────────────────────────────────────────────────────
final expenseServiceProvider =
    ChangeNotifierProvider<ExpenseService>((ref) {
  return ExpenseService(ref.read(notificationProvider));
});

// ── Payment ─────────────────────────────────────────────────────────────────
final paymentServiceProvider =
    ChangeNotifierProvider<PaymentService>((ref) {
  return PaymentService();
});

// ── Stateless services ─────────────────────────────────────────────────────
final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});
final reorderAlertServiceProvider = Provider<ReorderAlertService>((ref) {
  return ReorderAlertService(ref.read(databaseProvider).stockLedgerDao);
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(ref.read(databaseProvider));
});

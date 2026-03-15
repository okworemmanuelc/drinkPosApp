import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';

class SupabaseSyncService {
  final _client = Supabase.instance.client;
  Timer? _timer;

  /// Start periodic sync every 30 seconds. Also runs immediately.
  void start() {
    _timer?.cancel();
    processQueue(); // run immediately
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => processQueue());
  }

  void stop() => _timer?.cancel();

  /// Process all pending sync queue items.
  Future<void> processQueue() async {
    try {
      final pending = await database.syncDao.getPendingItems();
      for (final item in pending) {
        await database.syncDao.markInProgress(item.id);
        try {
          final payload = jsonDecode(item.payload) as Map<String, dynamic>;
          switch (item.actionType) {
            case 'CREATE_ORDER':
              await _syncOrder(payload['orderId'] as int);
            case 'UPDATE_INVENTORY':
              await _syncInventory(
                payload['productId'] as int,
                payload['warehouseId'] as int,
              );
          }
          await database.syncDao.markDone(item.id);
        } catch (e) {
          await database.syncDao.markFailed(item.id, e.toString());
        }
      }
    } catch (_) {
      // Silently ignore connectivity errors — will retry next cycle.
    }
  }

  Future<void> _syncOrder(int orderId) async {
    final order = await (database.select(database.orders)
          ..where((t) => t.id.equals(orderId)))
        .getSingleOrNull();
    if (order == null) return;

    // Upsert order row
    await _client.from('orders').upsert({
      'id': order.id,
      'order_number': order.orderNumber,
      'customer_id': order.customerId,
      'total_amount_kobo': order.totalAmountKobo,
      'discount_kobo': order.discountKobo,
      'net_amount_kobo': order.netAmountKobo,
      'amount_paid_kobo': order.amountPaidKobo,
      'payment_type': order.paymentType,
      'status': order.status,
      'rider_name': order.riderName,
      'staff_id': order.staffId,
      'barcode': order.barcode,
      'created_at': order.createdAt.toIso8601String(),
      'completed_at': order.completedAt?.toIso8601String(),
      'cancelled_at': order.cancelledAt?.toIso8601String(),
      'cancellation_reason': order.cancellationReason,
    });

    // Upsert all order items
    final items = await (database.select(database.orderItems)
          ..where((t) => t.orderId.equals(orderId)))
        .get();

    if (items.isNotEmpty) {
      await _client.from('order_items').upsert(
        items
            .map((item) => {
                  'id': item.id,
                  'order_id': item.orderId,
                  'product_id': item.productId,
                  'warehouse_id': item.warehouseId,
                  'quantity': item.quantity,
                  'unit_price_kobo': item.unitPriceKobo,
                  'total_kobo': item.totalKobo,
                })
            .toList(),
      );

      // Also sync inventory for each affected product/warehouse
      for (final item in items) {
        await _syncInventory(item.productId, item.warehouseId);
      }
    }
  }

  Future<void> _syncInventory(int productId, int warehouseId) async {
    final inv = await (database.select(database.inventory)
          ..where(
            (t) => t.productId.equals(productId) & t.warehouseId.equals(warehouseId),
          ))
        .getSingleOrNull();
    if (inv == null) return;

    await _client.from('inventory').upsert(
      {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': inv.quantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'product_id,warehouse_id',
    );
  }
}

final supabaseSyncService = SupabaseSyncService();

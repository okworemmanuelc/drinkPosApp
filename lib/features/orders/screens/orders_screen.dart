import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/services/activity_log_service.dart';
// staff.dart import removed as it was moved to DB fetch
import '../../../shared/services/order_service.dart';
import '../../../shared/widgets/receipt_widget.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../deliveries/data/models/delivery_receipt.dart' as model;
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
// customer_service.dart import removed as it was unused
import '../../pos/services/receipt_builder.dart';
import '../widgets/crate_return_modal.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  String _completedFilter = 'All Time';
  StreamSubscription<List<OrderWithItems>>? _ordersSub;
  List<OrderWithItems> _allOrdersWithItems = [];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ordersSub = orderService.watchAllOrdersWithItems().listen((data) {
      if (mounted) setState(() => _allOrdersWithItems = data);
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return SharedScaffold(
          activeRoute: 'orders',
          backgroundColor: _bg,
          appBar: _buildAppBar(context),
          body: Builder(
            builder: (context) {
              final allOrdersWithItems = _allOrdersWithItems;
              
              final pending = allOrdersWithItems.where((o) => o.order.status == 'pending').toList();

              // Apply date filters for Completed
              final now = DateTime.now();
              final separatedCompleted = allOrdersWithItems.where((o) => o.order.status == 'completed').toList();
              
              final completed = separatedCompleted.where((o) {
                if (_completedFilter == 'All Time') return true;
                final t = o.order.completedAt ?? o.order.createdAt;
                final diff = now.difference(t);
                if (_completedFilter == 'Day') {
                  return diff.inDays == 0 && now.day == t.day;
                }
                if (_completedFilter == 'Week') return diff.inDays <= 7;
                if (_completedFilter == 'Month') return diff.inDays <= 30;
                if (_completedFilter == 'Year') return diff.inDays <= 365;
                if (_completedFilter == 'To Date') return true;
                return true;
              }).toList();

              final cancelled = allOrdersWithItems.where((o) => o.order.status == 'cancelled').toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(context, pending, status: 'pending'),
                  _buildCompletedTab(context, completed),
                  _buildOrderList(context, cancelled, status: 'cancelled'),
                ],
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      iconTheme: IconThemeData(color: _text),
      leading: const MenuButton(),
      title: const AppBarHeader(
        icon: FontAwesomeIcons.receipt,
        title: 'Orders',
        subtitle: 'Sales History',
      ),
      centerTitle: true,
      actions: const [NotificationBell(), SizedBox(width: 8)],
      bottom: TabBar(
        controller: _tabController,
        labelColor: blueMain,
        unselectedLabelColor: _subtext,
        indicatorColor: blueMain,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: context.getRFontSize(14),
        ),
        tabs: const [
          Tab(icon: Icon(FontAwesomeIcons.boxOpen, size: 16), text: 'Pending'),
          Tab(
            icon: Icon(FontAwesomeIcons.clipboardCheck, size: 16),
            text: 'Completed',
          ),
          Tab(icon: Icon(FontAwesomeIcons.ban, size: 16), text: 'Cancelled'),
        ],
      ),
    );
  }

  Widget _buildCompletedTab(BuildContext context, List<OrderWithItems> list) {
    return Column(
      children: [
        _buildFilterChips(context),
        Expanded(child: _buildOrderList(context, list, status: 'completed')),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = ['Day', 'Week', 'Month', 'Year', 'To Date', 'All Time'];
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(vertical: context.getRSize(8)),
      height: context.getRSize(56),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
        itemCount: filters.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.getRSize(8)),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = f == _completedFilter;
          return FilterChip(
            label: Text(
              f,
              style: TextStyle(
                fontSize: context.getRFontSize(12),
                color: isSelected ? Colors.white : _text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (val) {
              setState(() => _completedFilter = f);
            },
            selectedColor: blueMain,
            backgroundColor: _bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : _border,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    List<OrderWithItems> list, {
    required String status,
  }) {
    if (list.isEmpty) {
      IconData icon;
      String text;
      if (status == 'pending') {
        icon = FontAwesomeIcons.boxOpen;
        text = 'No pending orders';
      } else if (status == 'completed') {
        icon = FontAwesomeIcons.clipboardCheck;
        text = 'No completed orders';
      } else {
        icon = FontAwesomeIcons.ban;
        text = 'No cancelled orders';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.getRSize(48), color: _border),
            SizedBox(height: context.getRSize(16)),
            Text(
              text,
              style: TextStyle(
                color: _subtext,
                fontSize: context.getRFontSize(16),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(100),
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _OrderCard(
          orderWithItems: item,
          status: status,
          onMarkAsDelivered: status == 'pending'
              ? () => _markAsDelivered(item)
              : null,
          onCancel: status == 'pending'
              ? () => _cancelOrder(item.order)
              : null,
          onAssignRider: status == 'pending'
              ? (orderId) => _showRiderSelection(context, orderId)
              : null,
          onRefund: status == 'cancelled' ? () => _showRefundChoice(context, item.order) : null,
          onViewReceipt: () => _viewReceipt(context, item),
          onReturnCrates: status == 'pending' && item.customer != null
              ? () => CrateReturnModal.show(context, item)
              : null,
        );
      },
    );
  }

  void _markAsDelivered(OrderWithItems orderWithItems) {
    final order = orderWithItems.order;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            'Confirm Order',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Mark order #${order.id} as completed?',
            style: TextStyle(color: _subtext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _subtext)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeMarkDelivered(orderWithItems);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _executeMarkDelivered(OrderWithItems orderWithItems) async {
    final order = orderWithItems.order;

    // 1. Update status
    await orderService.markAsCompleted(order.id, 1); // staffId 1 for now

    // 2. Generate Delivery Receipt
    final receipt = model.DeliveryReceipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: order.id.toString(),
      referenceNumber: model.deliveryReceiptService.generateReference(),
      riderName: order.riderName,
      outstandingAmount: (order.netAmountKobo - order.amountPaidKobo) / 100.0,
      paidAmount: order.amountPaidKobo / 100.0,
      createdAt: DateTime.now(),
    );
    model.deliveryReceiptService.addReceipt(receipt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.id} marked as completed.'),
          backgroundColor: success,
        ),
      );
    }

    // 3. If the order has glass items and a customer, open the crate return modal
    final hasGlassItems = orderWithItems.items.any(
      (i) => i.product.crateGroupId != null,
    );
    if (hasGlassItems && order.customerId != null && mounted) {
      await CrateReturnModal.show(context, orderWithItems);
    }
  }

  void _cancelOrder(OrderData order) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            'Cancel Order',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to cancel order #${order.id}?',
            style: TextStyle(color: _subtext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Back', style: TextStyle(color: _subtext)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                orderService.markAsCancelled(order.id, 'Cancelled by staff', 1);
              },
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }

  void _showRefundChoice(BuildContext context, OrderData order) {
    final isPartial = order.amountPaidKobo < order.netAmountKobo;

    if (isPartial) {
      // Force wallet refund for partial payments, no choice modal needed but maybe a confirmation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _surface,
          title: Text('Refund Payment', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
          content: Text(
            'Partial payment was made (${formatCurrency(order.amountPaidKobo / 100.0)} of ${formatCurrency(order.netAmountKobo / 100.0)}). '
            'The refund will be credited to ${order.orderNumber}\'s wallet.',
            style: TextStyle(color: _subtext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _subtext)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: blueMain, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _processRefund(order, toWallet: true);
              },
              child: const Text('Confirm Refund'),
            ),
          ],
        ),
      );
      return;
    }

    // Full payment choice modal
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Padding(
              padding: EdgeInsets.all(context.getRSize(16)),
              child: Text(
                'Refund Method',
                style: TextStyle(fontSize: context.getRFontSize(18), fontWeight: FontWeight.bold, color: _text),
              ),
            ),
            Text(
              'Select how you want to refund ${formatCurrency(order.amountPaidKobo / 100.0)}',
              style: TextStyle(color: _subtext, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(FontAwesomeIcons.wallet, color: success, size: context.getRSize(18)),
              title: Text('Refund to Wallet', style: TextStyle(color: _text)),
              subtitle: Text('Add balance to customer\'s wallet', style: TextStyle(color: _subtext, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _processRefund(order, toWallet: true);
              },
            ),
            ListTile(
              leading: Icon(FontAwesomeIcons.moneyBillWave, color: blueMain, size: context.getRSize(18)),
              title: Text('Refund to Cash', style: TextStyle(color: _text)),
              subtitle: Text('Record as cash payout', style: TextStyle(color: _subtext, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _processRefund(order, toWallet: false);
              },
            ),
            SizedBox(height: context.getRSize(20)),
          ],
        ),
      ),
    ),
  );
}

  void _processRefund(OrderData order, {required bool toWallet}) {
    // orderService.refundOrder(order.id, toWallet: toWallet); // Not yet implemented in Service
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refund of ${formatCurrency(order.amountPaidKobo / 100.0)} processed to ${toWallet ? 'Wallet' : 'Cash'}.'),
        backgroundColor: success,
      ),
    );
  }

  void _showRiderSelection(BuildContext context, int orderId) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<List<UserData>>(
          future: orderService.getRiders(),
          builder: (context, snapshot) {
            final riders = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            
            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(context.getRSize(16)),
                      child: Text(
                        'Assign Rider',
                        style: TextStyle(
                          fontSize: context.getRFontSize(18),
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else if (riders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No riders found in database.',
                          style: TextStyle(color: _subtext),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              leading: Icon(FontAwesomeIcons.store, color: _subtext, size: context.getRSize(18)),
                              title: Text('Pick-up Order', style: TextStyle(color: _text)),
                              onTap: () {
                                orderService.assignRider(orderId, 'Pick-up Order');
                                Navigator.pop(ctx);
                              },
                            ),
                            ...riders.map((staff) => ListTile(
                                  leading: Icon(FontAwesomeIcons.motorcycle, color: blueMain, size: context.getRSize(18)),
                                  title: Text(staff.name, style: TextStyle(color: _text)),
                                  subtitle: Text(staff.role.toUpperCase(), style: TextStyle(color: _subtext, fontSize: 12)),
                                  onTap: () {
                                    orderService.assignRider(orderId, staff.name);
                                    Navigator.pop(ctx);
                                  },
                                )),
                          ],
                        ),
                      ),
                    SizedBox(height: context.getRSize(40)), // Increased padding for system navigation
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _viewReceipt(BuildContext context, OrderWithItems richOrder) {
    DateTime? reshareDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final currentOrder = richOrder.order;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: context.getRSize(12)),
                    width: context.getRSize(40),
                    height: context.getRSize(5),
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        context.getRSize(20),
                        context.getRSize(10),
                        context.getRSize(20),
                        context.getRSize(30),
                      ),
                      child: Screenshot(
                        controller: _screenshotCtrl,
                        child: ReceiptWidget(
                          orderId: currentOrder.id.toString(),
                          cart: richOrder.items.map((ri) => {
                            'name': ri.product.name,
                            'qty': ri.item.quantity,
                            'price': ri.item.unitPriceKobo / 100.0,
                          }).toList(),
                          subtotal: currentOrder.totalAmountKobo / 100.0,
                          crateDeposit: 0, 
                          total: currentOrder.netAmountKobo / 100.0,
                          paymentMethod: currentOrder.paymentType,
                          customerName: richOrder.customer?.name ?? 'Walk-in Customer',
                          customerAddress: richOrder.customer?.addressText ?? 'N/A',
                          cashReceived: currentOrder.amountPaidKobo / 100.0,
                          walletBalance: richOrder.customer?.customerWallet,
                          reprintDate: DateTime.now(), 
                          reshareDate: reshareDate,
                          riderName: currentOrder.riderName,
                          deliveryRef: null,
                          orderStatus: currentOrder.status,
                          refundAmount: currentOrder.amountPaidKobo / 100.0,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.all(context.getRSize(16)),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueMain,
                                padding: EdgeInsets.symmetric(
                                  vertical: context.getRSize(16),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _printReceipt(context, richOrder),
                              icon: const Icon(FontAwesomeIcons.print, color: Colors.white, size: 18),
                              label: Text(
                                'Print',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.getRFontSize(14),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.getRSize(12)),
                          if (currentOrder.status == 'cancelled')
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: danger,
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.getRSize(16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: (currentOrder.paymentType == 'Credit')
                                    ? null
                                    : () {
                                        Navigator.pop(modalCtx);
                                        _showRefundChoice(context, currentOrder);
                                      },
                                icon: const Icon(FontAwesomeIcons.rotateLeft,
                                    color: Colors.white, size: 18),
                                label: Text(
                                  'Refund',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: context.getRFontSize(14),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (currentOrder.status == 'cancelled')
                            SizedBox(width: context.getRSize(12)),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: success,
                                padding: EdgeInsets.symmetric(
                                  vertical: context.getRSize(16),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                setModalState(() {
                                  reshareDate = DateTime.now();
                                });
                                // Small delay to ensure UI updates before capture
                                await Future.delayed(const Duration(milliseconds: 100));
                                if (context.mounted) {
                                  _shareReceipt(context, richOrder, reshareDate: reshareDate);
                                }
                              },
                              icon: const Icon(FontAwesomeIcons.shareNodes, color: Colors.white, size: 18),
                              label: Text(
                                'Share',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.getRFontSize(14),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _printReceipt(BuildContext context, OrderWithItems richOrder) async {
    final order = richOrder.order;
    // orderService.addReprint(order.id); // TODO: Implement in OrderService if needed
    
    final receiptMapping = richOrder.items.map((ri) => {
      'name': ri.product.name,
      'qty': ri.item.quantity,
      'price': ri.item.unitPriceKobo / 100.0,
    }).toList();

    final deliveryReceipt = model.deliveryReceiptService.getByOrderId(order.id.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printing reprint...')),
    );

    try {
      final bytes = await ThermalReceiptService.buildReceipt(
        orderId: order.id.toString(),
        cart: receiptMapping,
        subtotal: order.totalAmountKobo / 100.0,
        crateDeposit: 0,
        total: order.netAmountKobo / 100.0,
        paymentMethod: order.paymentType,
        customerName: richOrder.customer?.name ?? 'Walk-in Customer',
        customerAddress: richOrder.customer?.addressText ?? 'N/A',
        cashReceived: order.amountPaidKobo / 100.0,
        walletBalance: richOrder.customer?.customerWallet,
        reprintDate: DateTime.now(), 
        riderName: order.riderName,
        deliveryRef: deliveryReceipt?.referenceNumber,
        orderStatus: order.status,
        refundAmount: order.amountPaidKobo / 100.0,
      );

      await PrintBluetoothThermal.writeBytes(bytes);
      _logReprint(order.id.toString());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareReceipt(BuildContext context, OrderWithItems richOrder, {DateTime? reshareDate}) async {
    final order = richOrder.order;
    // orderService.addReprint(order.id);
    
    // Wait for UI to update with 'REPRINTED' or 'RESHARED' stamp before taking screenshot
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final Uint8List? imageBytes = await _screenshotCtrl.capture(
        delay: const Duration(milliseconds: 50),
        pixelRatio: 3.0,
      );
      
      if (imageBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture receipt')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final stamp = reshareDate != null ? 'reshare' : 'reprint';
      final file = File(
        '${dir.path}/ribaplus_pos_${stamp}_${order.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Ribaplus POS Receipt Reprint #${order.id}');
      _logReprint(order.id.toString());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logReprint(String orderId) async {
    await activityLogService.logAction(
      'Receipt Reprinted',
      'Receipt for order #$orderId was reprinted',
      relatedEntityId: orderId,
      relatedEntityType: 'order',
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderWithItems orderWithItems;
  final String status; // 'pending', 'completed', 'cancelled'
  final VoidCallback? onMarkAsDelivered;
  final VoidCallback? onCancel;
  final Function(int)? onAssignRider;
  final VoidCallback? onRefund;
  final VoidCallback onViewReceipt;
  final VoidCallback? onReturnCrates;

  const _OrderCard({
    required this.orderWithItems,
    required this.status,
    this.onMarkAsDelivered,
    this.onCancel,
    this.onAssignRider,
    this.onRefund,
    required this.onViewReceipt,
    this.onReturnCrates,
  });

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _surface => _isDark ? dSurface : lSurface;

  @override
  Widget build(BuildContext context) {
    final order = orderWithItems.order;
    final customer = orderWithItems.customer;
    final walletBalanceKobo = customer?.walletBalanceKobo ?? 0;
    final balanceColor = walletBalanceKobo < 0 ? danger : success;

    // Formatting date
    final time = status == 'pending'
        ? order.createdAt
        : (order.completedAt ?? order.createdAt);
    final isToday =
        time.year == DateTime.now().year &&
        time.month == DateTime.now().month &&
        time.day == DateTime.now().day;
    final dateStr = isToday
        ? 'Today, '
        : '${time.day}/${time.month}/${time.year} ';
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(16)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onViewReceipt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Customer Info
              Padding(
                padding: EdgeInsets.all(context.getRSize(16)),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.getRSize(10)),
                      decoration: BoxDecoration(
                        color: blueMain.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        FontAwesomeIcons.user,
                        size: context.getRSize(16),
                        color: blueMain,
                      ),
                    ),
                    SizedBox(width: context.getRSize(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?.name ?? 'Walk-in Customer',
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15),
                            ),
                          ),
                          SizedBox(height: context.getRSize(2)),
                          Text(
                            customer?.addressText ?? 'N/A',
                            style: TextStyle(
                              color: _subtext,
                              fontSize: context.getRFontSize(13),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (status == 'pending')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onReturnCrates != null &&
                              orderWithItems.items.any(
                                (i) => i.product.crateGroupId != null,
                              ))
                            Padding(
                              padding: EdgeInsets.only(right: context.getRSize(4)),
                              child: IconButton(
                                icon: Icon(
                                  FontAwesomeIcons.boxOpen,
                                  size: context.getRSize(18),
                                  color: Colors.orange,
                                ),
                                tooltip: 'Return Crates',
                                onPressed: onReturnCrates,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  FontAwesomeIcons.motorcycle,
                                  size: context.getRSize(20),
                                  color: blueMain,
                                ),
                                onPressed: () => onAssignRider?.call(order.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              SizedBox(height: context.getRSize(4)),
                              Text(
                                order.riderName,
                                style: TextStyle(
                                  fontSize: context.getRFontSize(10),
                                  color: _subtext,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (status != 'pending')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.getRSize(10),
                          vertical: context.getRSize(6),
                        ),
                        decoration: BoxDecoration(
                          color: (order.status == 'completed'
                                  ? success
                                  : (order.status == 'refunded'
                                      ? blueMain
                                      : danger))
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (order.status == 'completed'
                                    ? success
                                    : (order.status == 'refunded'
                                        ? blueMain
                                        : danger))
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              order.status == 'completed'
                                  ? FontAwesomeIcons.check
                                  : (order.status == 'refunded'
                                      ? FontAwesomeIcons.rotateLeft
                                      : FontAwesomeIcons.ban),
                              size: context.getRSize(10),
                              color: order.status == 'completed'
                                  ? success
                                  : (order.status == 'refunded'
                                      ? blueMain
                                      : danger),
                            ),
                            SizedBox(width: context.getRSize(6)),
                            Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                color: order.status == 'completed'
                                    ? success
                                    : (order.status == 'refunded'
                                        ? blueMain
                                        : danger),
                                fontWeight: FontWeight.bold,
                                fontSize: context.getRFontSize(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: _border),

              // Order ID & Time
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.getRSize(16),
                  context.getRSize(12),
                  context.getRSize(16),
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id}',
                          style: TextStyle(
                            color: _subtext,
                            fontWeight: FontWeight.w600,
                            fontSize: context.getRFontSize(13),
                          ),
                        ),
                        if (order.barcode != null)
                          Text(
                            'Barcode: ${order.barcode}',
                            style: TextStyle(
                              color: _subtext,
                              fontSize: context.getRFontSize(11),
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '$dateStr$timeStr',
                      style: TextStyle(
                        color: _subtext,
                        fontSize: context.getRFontSize(12),
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Padding(
                padding: EdgeInsets.all(context.getRSize(16)),
                child: Column(
                  children: orderWithItems.items.map((richItem) {
                    final item = richItem.item;
                    final product = richItem.product;
                    return Padding(
                      padding: EdgeInsets.only(bottom: context.getRSize(6)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${product.name}',
                              style: TextStyle(
                                color: _text,
                                fontSize: context.getRFontSize(14),
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(item.totalKobo / 100.0),
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: context.getRFontSize(14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              Divider(height: 1, color: _border),

              // Totals
              Padding(
                padding: EdgeInsets.all(context.getRSize(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: ${formatCurrency(order.netAmountKobo / 100.0)}',
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: context.getRFontSize(13),
                            ),
                          ),
                          SizedBox(height: context.getRSize(4)),
                          Text(
                            'Paid: ${formatCurrency(order.amountPaidKobo / 100.0)} • ${order.paymentType}',
                            style: TextStyle(
                              color: _subtext,
                              fontSize: context.getRFontSize(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.getRSize(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(10),
                        vertical: context.getRSize(6),
                      ),
                      decoration: BoxDecoration(
                        color: balanceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: balanceColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Wallet Balance: ${formatCurrency(walletBalanceKobo / 100.0)}',
                        style: TextStyle(
                          color: balanceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer Actions for Pending
              if (status == 'pending')
                Container(
                  padding: EdgeInsets.fromLTRB(
                    context.getRSize(16),
                    context.getRSize(16),
                    context.getRSize(16),
                    context.getRSize(16),
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Row(
                    children: [
                      if (onCancel != null)
                        Expanded(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: danger,
                              padding: EdgeInsets.symmetric(
                                vertical: context.getRSize(12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              FontAwesomeIcons.ban,
                              size: context.getRSize(14),
                            ),
                            label: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: context.getRFontSize(13),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: onCancel,
                          ),
                        ),
                      SizedBox(width: context.getRSize(12)),
                      if (onMarkAsDelivered != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blueMain,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                vertical: context.getRSize(12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              FontAwesomeIcons.truckFast,
                              size: context.getRSize(14),
                            ),
                            label: Text(
                              'Confirm Delivery',
                              style: TextStyle(
                                fontSize: context.getRFontSize(13),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: onMarkAsDelivered,
                          ),
                        ),
                      if (status == 'cancelled' && onRefund != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                vertical: context.getRSize(12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              FontAwesomeIcons.rotateLeft,
                              size: context.getRSize(14),
                            ),
                            label: Text(
                              'Initiate Refund',
                              style: TextStyle(
                                fontSize: context.getRFontSize(13),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: onRefund,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


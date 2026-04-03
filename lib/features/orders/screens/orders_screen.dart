import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:reebaplus_pos/core/theme/colors.dart';

import 'package:reebaplus_pos/core/utils/number_format.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/services/activity_log_service.dart';
// staff.dart import removed as it was moved to DB fetch
import 'package:reebaplus_pos/shared/services/order_service.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/receipt_widget.dart';
import 'package:reebaplus_pos/shared/widgets/shared_scaffold.dart';
import 'package:reebaplus_pos/features/deliveries/data/models/delivery_receipt.dart'
    as model;
import 'package:reebaplus_pos/shared/widgets/menu_button.dart';
import 'package:reebaplus_pos/shared/widgets/app_bar_header.dart';
import 'package:reebaplus_pos/shared/widgets/notification_bell.dart';

// customer_service.dart import removed as it was unused
import 'package:reebaplus_pos/features/pos/services/receipt_builder.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/orders/widgets/crate_return_modal.dart';
import 'package:reebaplus_pos/shared/services/printer_service.dart';
import 'package:reebaplus_pos/shared/widgets/printer_picker.dart';
import 'package:reebaplus_pos/shared/widgets/shimmer_loading.dart';

class OrdersScreen extends StatefulWidget {
  final int initialIndex;
  const OrdersScreen({super.key, this.initialIndex = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  String _completedFilter = 'All Time';
  bool _isFirstLoad = true;
  StreamSubscription<List<OrderWithItems>>? _ordersSub;
  List<OrderWithItems> _allOrdersWithItems = [];
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceCol => Theme.of(context).colorScheme.surface;
  Color get textCol => Theme.of(context).colorScheme.onSurface;
  Color get subtextCol =>
      Theme.of(context).textTheme.bodySmall?.color ??
      Theme.of(context).iconTheme.color!;
  Color get borderCol => Theme.of(context).dividerColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    final minLoading = Future.delayed(const Duration(seconds: 2));

    _ordersSub = orderService.watchAllOrdersWithItems().listen((data) async {
      await minLoading;
      if (mounted) {
        setState(() {
          _allOrdersWithItems = data;
          _isFirstLoad = false;
        });
      }
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
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
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

              final pending = allOrdersWithItems
                  .where((o) => o.order.status == 'pending')
                  .toList();

              // Apply date filters for Completed
              final now = DateTime.now();
              final separatedCompleted = allOrdersWithItems
                  .where((o) => o.order.status == 'completed')
                  .toList();

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

              final cancelled = allOrdersWithItems
                  .where((o) => o.order.status == 'cancelled')
                  .toList();

              if (_isFirstLoad) {
                return const SingleChildScrollView(
                  child: ShimmerOrderList(count: 7),
                );
              }

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
      backgroundColor: surfaceCol,
      elevation: 0,
      iconTheme: IconThemeData(color: textCol),
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
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: subtextCol,
        indicatorColor: Theme.of(context).colorScheme.primary,
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
      color: surfaceCol,
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
                color: isSelected ? Colors.white : textCol,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (val) {
              setState(() => _completedFilter = f);
            },
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: _bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : borderCol,
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
            Icon(icon, size: context.getRSize(48), color: borderCol),
            SizedBox(height: context.getRSize(16)),
            Text(
              text,
              style: TextStyle(
                color: subtextCol,
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
          onCancel: status == 'pending' ? () => _cancelOrder(item.order) : null,
          onAssignRider: status == 'pending'
              ? (orderId) => _showRiderSelection(context, orderId)
              : null,
          onRefund: status == 'cancelled'
              ? () => _showRefundChoice(context, item.order)
              : null,
          onViewReceipt: () => _viewReceipt(context, item),
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
          backgroundColor: surfaceCol,
          title: Text(
            'Confirm Order',
            style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Mark order #${order.id} as completed?',
            style: TextStyle(color: subtextCol),
          ),
          actions: [
            AppButton(
              text: 'Cancel',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              text: 'Confirm',
              onPressed: () {
                Navigator.pop(ctx);
                _executeMarkDelivered(orderWithItems);
              },
              size: AppButtonSize.small,
            ),
          ],
        );
      },
    );
  }

  void _executeMarkDelivered(OrderWithItems orderWithItems) async {
    final order = orderWithItems.order;

    // 1. Show crate return modal FIRST — must be confirmed before completing.
    // CrateReturnModal.show() handles its own guards (no glass items / deposit
    // already paid) and returns immediately in those cases. The modal is
    // non-dismissible, so awaiting it guarantees the user has confirmed.
    if (order.customerId != null && mounted) {
      await CrateReturnModal.show(context, orderWithItems);
    }

    if (!mounted) return;

    // 2. Only now mark the order as completed
    await orderService.markAsCompleted(
      order.id,
      authService.currentUser?.id ?? 1,
    );

    // 3. Generate Delivery Receipt
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

    // 4. Show success notification only after everything is confirmed
    if (mounted) {
      AppNotification.showSuccess(
        context,
        'Order #${order.id} marked as completed.',
      );
    }
  }

  void _cancelOrder(OrderData order) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surfaceCol,
          title: Text(
            'Cancel Order',
            style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to cancel order #${order.id}?',
            style: TextStyle(color: subtextCol),
          ),
          actions: [
            AppButton(
              text: 'Back',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              text: 'Cancel Order',
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: () {
                Navigator.pop(ctx);
                orderService.markAsCancelled(order.id, 'Cancelled by staff', 1);
              },
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
          backgroundColor: surfaceCol,
          title: Text(
            'Refund Payment',
            style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Partial payment was made (${formatCurrency(order.amountPaidKobo / 100.0)} of ${formatCurrency(order.netAmountKobo / 100.0)}). '
            'The refund will be credited to ${order.orderNumber}\'s wallet.',
            style: TextStyle(color: subtextCol),
          ),
          actions: [
            AppButton(
              text: 'Cancel',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppButton(
              text: 'Confirm Refund',
              size: AppButtonSize.small,
              onPressed: () {
                Navigator.pop(ctx);
                _processRefund(order, toWallet: true);
              },
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
            color: surfaceCol,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(context.getRSize(16)),
                child: Text(
                  'Refund Method',
                  style: TextStyle(
                    fontSize: context.getRFontSize(18),
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                ),
              ),
              Text(
                'Select how you want to refund ${formatCurrency(order.amountPaidKobo / 100.0)}',
                style: TextStyle(color: subtextCol, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  FontAwesomeIcons.wallet,
                  color: success,
                  size: context.getRSize(18),
                ),
                title: Text(
                  'Refund to Wallet',
                  style: TextStyle(color: textCol),
                ),
                subtitle: Text(
                  'Add balance to customer\'s wallet',
                  style: TextStyle(color: subtextCol, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _processRefund(order, toWallet: true);
                },
              ),
              ListTile(
                leading: Icon(
                  FontAwesomeIcons.moneyBillWave,
                  color: Theme.of(context).colorScheme.primary,
                  size: context.getRSize(18),
                ),
                title: Text('Refund to Cash', style: TextStyle(color: textCol)),
                subtitle: Text(
                  'Record as cash payout',
                  style: TextStyle(color: subtextCol, fontSize: 12),
                ),
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
    AppNotification.showSuccess(
      context,
      'Refund of ${formatCurrency(order.amountPaidKobo / 100.0)} processed to ${toWallet ? 'Wallet' : 'Cash'}.',
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
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceCol,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
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
                          color: textCol,
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
                          style: TextStyle(color: subtextCol),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              leading: Icon(
                                FontAwesomeIcons.store,
                                color: subtextCol,
                                size: context.getRSize(18),
                              ),
                              title: Text(
                                'Pick-up Order',
                                style: TextStyle(color: textCol),
                              ),
                              onTap: () {
                                orderService.assignRider(
                                  orderId,
                                  'Pick-up Order',
                                );
                                Navigator.pop(ctx);
                              },
                            ),
                            ...riders.map(
                              (staff) => ListTile(
                                leading: Icon(
                                  FontAwesomeIcons.motorcycle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: context.getRSize(18),
                                ),
                                title: Text(
                                  staff.name,
                                  style: TextStyle(color: textCol),
                                ),
                                subtitle: Text(
                                  staff.role.toUpperCase(),
                                  style: TextStyle(
                                    color: subtextCol,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  orderService.assignRider(orderId, staff.name);
                                  Navigator.pop(ctx);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: context.getRSize(40),
                    ), // Increased padding for system navigation
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
    DateTime? reprintDate;

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
                color: surfaceCol,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(
                      vertical: context.getRSize(12),
                    ),
                    width: context.getRSize(40),
                    height: context.getRSize(5),
                    decoration: BoxDecoration(
                      color: borderCol,
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
                          orderId: currentOrder.orderNumber,
                          cart: richOrder.items
                              .map(
                                (ri) => {
                                  'name': ri.product.name,
                                  'qty': ri.item.quantity,
                                  'price': ri.item.unitPriceKobo / 100.0,
                                },
                              )
                              .toList(),
                          subtotal: currentOrder.totalAmountKobo / 100.0,
                          crateDeposit: 0,
                          total: currentOrder.netAmountKobo / 100.0,
                          paymentMethod: currentOrder.paymentType,
                          customerName:
                              richOrder.customer?.name ?? 'Walk-in Customer',
                          customerAddress:
                              richOrder.customer?.addressText ?? 'N/A',
                          cashReceived: currentOrder.amountPaidKobo / 100.0,
                          walletBalance: richOrder.customer?.customerWallet,
                          reprintDate: reprintDate,
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
                            child: AppButton(
                              text: 'Print',
                              icon: FontAwesomeIcons.print,
                              onPressed: () {
                                setModalState(() {
                                  reprintDate = DateTime.now();
                                });
                                _printReceipt(context, richOrder);
                              },
                            ),
                          ),
                          SizedBox(width: context.getRSize(12)),
                          if (currentOrder.status == 'cancelled')
                            Expanded(
                              child: AppButton(
                                text: 'Refund',
                                icon: FontAwesomeIcons.rotateLeft,
                                variant: AppButtonVariant.danger,
                                onPressed:
                                    (currentOrder.paymentType == 'Credit')
                                    ? null
                                    : () {
                                        Navigator.pop(modalCtx);
                                        _showRefundChoice(
                                          context,
                                          currentOrder,
                                        );
                                      },
                              ),
                            ),
                          if (currentOrder.status == 'cancelled')
                            SizedBox(width: context.getRSize(12)),
                          Expanded(
                            child: AppButton(
                              text: 'Share',
                              icon: FontAwesomeIcons.shareNodes,
                              variant: AppButtonVariant.secondary,
                              onPressed: () async {
                                setModalState(() {
                                  reshareDate = DateTime.now();
                                });
                                // Small delay to ensure UI updates before capture
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                if (context.mounted) {
                                  _shareReceipt(
                                    context,
                                    richOrder,
                                    reshareDate: reshareDate,
                                  );
                                }
                              },
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
    ).then((_) {
      reshareDate = null;
      reprintDate = null;
    });
  }

  Future<void> _printReceipt(
    BuildContext context,
    OrderWithItems richOrder,
  ) async {
    final order = richOrder.order;

    final receiptMapping = richOrder.items
        .map(
          (ri) => {
            'name': ri.product.name,
            'qty': ri.item.quantity,
            'price': ri.item.unitPriceKobo / 100.0,
          },
        )
        .toList();

    final deliveryReceipt = model.deliveryReceiptService.getByOrderId(
      order.id.toString(),
    );

    try {
      final granted = await printerService.requestPermissions();
      if (!granted) {
        if (!context.mounted) return;
        AppNotification.showError(context, 'Bluetooth permissions denied');
        return;
      }

      final bytes = await ThermalReceiptService.buildReceipt(
        orderId: order.orderNumber,
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

      if (!context.mounted) return;

      final success = await printerService.printBytes(bytes);
      if (success) {
        if (!context.mounted) return;
        AppNotification.showSuccess(context, 'Print successful');
        _logReprint(order.id.toString());
        return;
      }

      // If print failed (not connected), show printer picker
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: surfaceCol,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => PrinterPicker(
            onSelected: (device) async {
              if (!context.mounted) return;
              Navigator.pop(context);

              if (!context.mounted) return;
              AppNotification.showSuccess(
                context,
                'Connecting to ${device.name}...',
              );

              final connected = await printerService.connect(device.macAdress);
              if (!mounted) return;

              if (connected) {
                await printerService.printBytes(bytes);
                if (!context.mounted) return;
                AppNotification.showSuccess(context, 'Print successful');
                _logReprint(order.id.toString());
              } else {
                if (!context.mounted) return;
                AppNotification.showError(
                  context,
                  'Failed to connect to ${device.name}',
                );
              }
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppNotification.showError(context, 'Error printing: $e');
      }
    }
  }

  Future<void> _shareReceipt(
    BuildContext context,
    OrderWithItems richOrder, {
    DateTime? reshareDate,
  }) async {
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
          AppNotification.showError(context, 'Failed to capture receipt');
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final stamp = reshareDate != null ? 'reshare' : 'reprint';
      final file = File(
        '${dir.path}/reebaplus_pos_${stamp}_${order.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reebaplus POS Receipt Reprint #${order.id}');
      _logReprint(order.id.toString());
    } catch (e) {
      if (context.mounted) {
        AppNotification.showError(context, 'Error sharing: $e');
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

  const _OrderCard({
    required this.orderWithItems,
    required this.status,
    this.onMarkAsDelivered,
    this.onCancel,
    this.onAssignRider,
    this.onRefund,
    required this.onViewReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final textCol = Theme.of(context).colorScheme.onSurface;
    final subtextCol =
        Theme.of(context).textTheme.bodySmall?.color ??
        Theme.of(context).iconTheme.color!;
    final borderCol = Theme.of(context).dividerColor;
    final cardCol = Theme.of(context).cardColor;
    final surfaceCol = Theme.of(context).colorScheme.surface;
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
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        FontAwesomeIcons.user,
                        size: context.getRSize(16),
                        color: Theme.of(context).colorScheme.primary,
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
                              color: textCol,
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15),
                            ),
                          ),
                          SizedBox(height: context.getRSize(2)),
                          Text(
                            customer?.addressText ?? 'N/A',
                            style: TextStyle(
                              color: subtextCol,
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
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  FontAwesomeIcons.motorcycle,
                                  size: context.getRSize(20),
                                  color: Theme.of(context).colorScheme.primary,
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
                                  color: subtextCol,
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
                          color:
                              (order.status == 'completed'
                                      ? success
                                      : (order.status == 'refunded'
                                            ? blueMain
                                            : danger))
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (order.status == 'completed'
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
              Divider(height: 1, color: borderCol),

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
                            color: subtextCol,
                            fontWeight: FontWeight.w600,
                            fontSize: context.getRFontSize(13),
                          ),
                        ),
                        if (order.barcode != null)
                          Text(
                            'Barcode: ${order.barcode}',
                            style: TextStyle(
                              color: subtextCol,
                              fontSize: context.getRFontSize(11),
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '$dateStr$timeStr',
                      style: TextStyle(
                        color: subtextCol,
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
                                color: textCol,
                                fontSize: context.getRFontSize(14),
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(item.totalKobo / 100.0),
                            style: TextStyle(
                              color: textCol,
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

              Divider(height: 1, color: borderCol),

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
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(14),
                            ),
                          ),
                          SizedBox(height: context.getRSize(4)),
                          Text(
                            'Paid: ${formatCurrency(order.amountPaidKobo / 100.0)} • ${order.paymentType}',
                            style: TextStyle(
                              color: subtextCol,
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
                    color: surfaceCol,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    border: Border(top: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      if (onCancel != null)
                        Expanded(
                          child: AppButton(
                            text: 'Cancel',
                            icon: FontAwesomeIcons.ban,
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.xsmall,
                            onPressed: onCancel,
                          ),
                        ),
                      SizedBox(width: context.getRSize(12)),
                      if (onMarkAsDelivered != null)
                        Expanded(
                          child: AppButton(
                            text: 'Confirm',
                            icon: FontAwesomeIcons.truckFast,
                            size: AppButtonSize.xsmall,
                            onPressed: onMarkAsDelivered,
                          ),
                        ),
                      if (status == 'cancelled' && onRefund != null)
                        Expanded(
                          child: AppButton(
                            text: 'Initiate Refund',
                            icon: FontAwesomeIcons.rotateLeft,
                            variant: AppButtonVariant.danger,
                            size: AppButtonSize.xsmall,
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

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/services/delivery_service.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/receipt_widget.dart';
import '../../customers/data/services/customer_service.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: _bg,
          drawer: const AppDrawer(activeRoute: 'deliveries'),
          appBar: _buildAppBar(context),
          body: ValueListenableBuilder<List<Delivery>>(
            valueListenable: deliveryService,
            builder: (context, deliveries, child) {
              final pending = deliveryService.getPending();
              final completed = deliveryService.getCompleted();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildDeliveryList(context, pending, isPending: true),
                  _buildDeliveryList(context, completed, isPending: false),
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
      title: Text(
        'Deliveries',
        style: TextStyle(
          color: _text,
          fontSize: context.getRFontSize(18),
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
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
          Tab(text: 'Pending'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildDeliveryList(
    BuildContext context,
    List<Delivery> list, {
    required bool isPending,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending
                  ? FontAwesomeIcons.boxOpen
                  : FontAwesomeIcons.clipboardCheck,
              size: context.getRSize(48),
              color: _border,
            ),
            SizedBox(height: context.getRSize(16)),
            Text(
              isPending ? 'No pending deliveries' : 'No completed deliveries',
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
      padding: EdgeInsets.all(context.getRSize(16)),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _DeliveryCard(
          delivery: list[index],
          isPending: isPending,
          onMarkAsDelivered: isPending
              ? () => _markAsDelivered(list[index])
              : null,
          onViewReceipt: () => _viewReceipt(context, list[index]),
        );
      },
    );
  }

  void _markAsDelivered(Delivery delivery) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          title: Text(
            'Confirm Delivery',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Mark order #${delivery.id} for ${delivery.customerName} as delivered?',
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
                _executeMarkDelivered(delivery);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _executeMarkDelivered(Delivery delivery) {
    // 1. Update status in deliveryService
    deliveryService.markAsCompleted(delivery.id);

    // 2. Map completion back to customer record if joined
    if (delivery.customerId != null) {
      final customer = customerService.getById(delivery.customerId!);
      if (customer != null) {
        // Here we could keep orderIds updated or tracking states,
        // For now, ensuring the order exists in the tracker is good practice.
        if (!customer.orderIds.contains(delivery.id)) {
          final updatedCustomer = customer.copyWith(
            orderIds: [...customer.orderIds, delivery.id],
          );
          customerService.updateCustomer(updatedCustomer);
        }
      }
    }

    // 3. Log action
    activityLogService.logAction(
      'Delivery Completed',
      'Order ${delivery.id} for ${delivery.customerName} marked as delivered',
      relatedEntityId: delivery.id,
      relatedEntityType: 'delivery',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${delivery.id} marked as delivered.'),
        backgroundColor: success,
      ),
    );
  }

  void _viewReceipt(BuildContext context, Delivery delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bump
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
                  child: ReceiptWidget(
                    orderId: delivery.id,
                    cart: delivery.items,
                    subtotal: _computeSubtotal(delivery.items),
                    crateDeposit: _computeCrateDeposit(delivery.items),
                    total: delivery.totalAmount,
                    paymentMethod: delivery.paymentMethod,
                    customerName: delivery.customerName,
                    customerAddress: delivery.customerAddress,
                    cashReceived: delivery.amountPaid > 0
                        ? delivery.amountPaid
                        : null,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(context.getRSize(16)),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueMain,
                        padding: EdgeInsets.symmetric(
                          vertical: context.getRSize(16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.getRFontSize(16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _computeSubtotal(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, i) => sum + (i['price'] * i['qty']));
  }

  double _computeCrateDeposit(List<Map<String, dynamic>> items) {
    return items.fold(
      0.0,
      (sum, i) =>
          sum +
          ((i['needsEmptyCrate'] == true)
              ? i['qty'] * 1500
              : 0.0), // using typical bottle logic, or map back correctly
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final bool isPending;
  final VoidCallback? onMarkAsDelivered;
  final VoidCallback onViewReceipt;

  const _DeliveryCard({
    required this.delivery,
    required this.isPending,
    this.onMarkAsDelivered,
    required this.onViewReceipt,
  });

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _surface => _isDark ? dSurface : lSurface;

  @override
  Widget build(BuildContext context) {
    final balanceColor = delivery.balance < 0 ? danger : success;

    // Formatting date
    final time = isPending
        ? delivery.createdAt
        : (delivery.completedAt ?? delivery.createdAt);
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
                        delivery.customerName,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(15),
                        ),
                      ),
                      SizedBox(height: context.getRSize(2)),
                      Text(
                        delivery.customerAddress,
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
                if (!isPending)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(10),
                      vertical: context.getRSize(6),
                    ),
                    decoration: BoxDecoration(
                      color: success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FontAwesomeIcons.check,
                          size: context.getRSize(10),
                          color: success,
                        ),
                        SizedBox(width: context.getRSize(6)),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: success,
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
                Text(
                  'Order #${delivery.id}',
                  style: TextStyle(
                    color: _subtext,
                    fontWeight: FontWeight.w600,
                    fontSize: context.getRFontSize(13),
                  ),
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
              children: delivery.items.map((item) {
                return Padding(
                  padding: EdgeInsets.only(bottom: context.getRSize(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['qty']}x ${item['name']}',
                          style: TextStyle(
                            color: _text,
                            fontSize: context.getRFontSize(14),
                          ),
                        ),
                      ),
                      Text(
                        '₦${fmtNumber((item['price'] * item['qty']).toInt())}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ₦${fmtNumber(delivery.totalAmount.toInt())}',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: context.getRFontSize(13),
                      ),
                    ),
                    SizedBox(height: context.getRSize(4)),
                    Text(
                      'Paid: ₦${fmtNumber(delivery.amountPaid.toInt())} • ${delivery.paymentMethod}',
                      style: TextStyle(
                        color: _subtext,
                        fontSize: context.getRFontSize(12),
                      ),
                    ),
                  ],
                ),
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
                    'Balance: ₦${fmtNumber(delivery.balance.toInt())}',
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer Actions
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(16),
              vertical: context.getRSize(12),
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
                // View receipt is always present
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: blueMain,
                      padding: EdgeInsets.symmetric(
                        vertical: context.getRSize(12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      FontAwesomeIcons.receipt,
                      size: context.getRSize(14),
                    ),
                    label: Text(
                      'View Receipt',
                      style: TextStyle(
                        fontSize: context.getRFontSize(13),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onViewReceipt,
                  ),
                ),
                if (isPending && onMarkAsDelivered != null) ...[
                  SizedBox(width: context.getRSize(12)),
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
                        'Mark Delivered',
                        style: TextStyle(
                          fontSize: context.getRFontSize(13),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onMarkAsDelivered,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

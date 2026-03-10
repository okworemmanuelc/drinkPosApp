import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/order.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/services/order_service.dart';
import '../../../shared/widgets/receipt_widget.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../customers/data/services/customer_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _completedFilter = 'All Time';

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
        return SharedScaffold(
          activeRoute: 'orders',
          backgroundColor: _bg,
          appBar: _buildAppBar(context),
          body: ValueListenableBuilder<List<Order>>(
            valueListenable: orderService,
            builder: (context, orders, child) {
              final pending = orderService.getPending();

              // Apply date filters for Completed
              final allCompleted = orderService.getCompleted();
              final now = DateTime.now();
              final completed = allCompleted.where((o) {
                if (_completedFilter == 'All Time') return true;
                final t = o.completedAt ?? o.createdAt;
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

              final cancelled = orderService.getCancelled();

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

  Widget _buildCompletedTab(BuildContext context, List<Order> list) {
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
    List<Order> list, {
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
        return _OrderCard(
          order: list[index],
          status: status,
          onMarkAsDelivered: status == 'pending'
              ? () => _markAsDelivered(list[index])
              : null,
          onCancel: status == 'pending'
              ? () => _cancelOrder(list[index])
              : null,
          onViewReceipt: () => _viewReceipt(context, list[index]),
        );
      },
    );
  }

  void _markAsDelivered(Order order) {
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
            'Mark order #${order.id} for ${order.customerName} as completed?',
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
                _executeMarkDelivered(order);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _executeMarkDelivered(Order order) {
    // 1. Update status
    orderService.markAsCompleted(order.id);

    // 2. Map completion back to customer record if joined
    if (order.customerId != null) {
      final customer = customerService.getById(order.customerId!);
      if (customer != null) {
        if (!customer.orderIds.contains(order.id)) {
          final updatedCustomer = customer.copyWith(
            orderIds: [...customer.orderIds, order.id],
          );
          customerService.updateCustomer(updatedCustomer);
        }
      }
    }

    // 3. Log action
    activityLogService.logAction(
      'Order Completed',
      'Order ${order.id} for ${order.customerName} marked as completed',
      relatedEntityId: order.id,
      relatedEntityType: 'order',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${order.id} marked as completed.'),
        backgroundColor: success,
      ),
    );
  }

  void _cancelOrder(Order order) {
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
                orderService.markAsCancelled(order.id);
                activityLogService.logAction(
                  'Order Cancelled',
                  'Order ${order.id} for ${order.customerName} was cancelled',
                  relatedEntityId: order.id,
                  relatedEntityType: 'order',
                );
              },
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }

  void _viewReceipt(BuildContext context, Order order) {
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
                    orderId: order.id,
                    cart: order.items,
                    subtotal: order.subtotal,
                    crateDeposit: order.crateDeposit,
                    total: order.totalAmount,
                    paymentMethod: order.paymentMethod,
                    customerName: order.customerName,
                    customerAddress: order.customerAddress,
                    cashReceived: order.amountPaid > 0
                        ? order.amountPaid
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
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final String status; // 'pending', 'completed', 'cancelled'
  final VoidCallback? onMarkAsDelivered;
  final VoidCallback? onCancel;
  final VoidCallback onViewReceipt;

  const _OrderCard({
    required this.order,
    required this.status,
    this.onMarkAsDelivered,
    this.onCancel,
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
    final balanceColor = order.customerWallet < 0 ? danger : success;

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
                            order.customerName,
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15),
                            ),
                          ),
                          SizedBox(height: context.getRSize(2)),
                          Text(
                            order.customerAddress,
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
                    if (status != 'pending')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.getRSize(10),
                          vertical: context.getRSize(6),
                        ),
                        decoration: BoxDecoration(
                          color: (status == 'completed' ? success : danger)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (status == 'completed' ? success : danger)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'completed'
                                  ? FontAwesomeIcons.check
                                  : FontAwesomeIcons.ban,
                              size: context.getRSize(10),
                              color: status == 'completed' ? success : danger,
                            ),
                            SizedBox(width: context.getRSize(6)),
                            Text(
                              status == 'completed' ? 'Completed' : 'Cancelled',
                              style: TextStyle(
                                color: status == 'completed' ? success : danger,
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
                      'Order #${order.id}',
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
                  children: order.items.map((item) {
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
                          'Total: ₦${fmtNumber(order.totalAmount.toInt())}',
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                            fontSize: context.getRFontSize(13),
                          ),
                        ),
                        SizedBox(height: context.getRSize(4)),
                        Text(
                          'Paid: ₦${fmtNumber(order.amountPaid.toInt())} • ${order.paymentMethod}',
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
                        'Balance: ₦${fmtNumber(order.customerWallet.toInt())}',
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

              // Footer Actions for Pending
              if (status == 'pending')
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
                              'Mark Completed',
                              style: TextStyle(
                                fontSize: context.getRFontSize(13),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: onMarkAsDelivered,
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

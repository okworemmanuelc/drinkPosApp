import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../inventory/data/models/crate_group.dart';
import '../data/models/customer.dart';
import '../data/models/payment.dart';
import '../data/services/customer_service.dart';
import '../../../shared/models/order.dart';
import '../../../shared/services/order_service.dart';
import '../../../shared/widgets/receipt_widget.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/number_format.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;

  String _getEmptyText(String filter, String type) {
    switch (filter) {
      case 'Day':
        return 'No $type today';
      case 'Week':
        return 'No $type this week';
      case 'Month':
        return 'No $type this month';
      case 'Year':
        return 'No $type this year';
      case 'All Time':
      default:
        return 'No $type found';
    }
  }

  @override
  void initState() {
    super.initState();
    _customer = customerService.getById(widget.customerId);
    customerService.addListener(_onCustomerUpdated);
  }

  @override
  void dispose() {
    customerService.removeListener(_onCustomerUpdated);
    super.dispose();
  }

  void _onCustomerUpdated() {
    if (mounted) {
      setState(() {
        _customer = customerService.getById(widget.customerId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_customer == null) {
      return const Scaffold(body: Center(child: Text("Customer not found.")));
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final bgCol = isDark ? dBg : lBg;
        final surfaceCol = isDark ? dSurface : lSurface;
        final textCol = isDark ? dText : lText;
        final subtextCol = isDark ? dSubtext : lSubtext;
        final borderCol = isDark ? dBorder : lBorder;
        final cardCol = isDark ? dCard : lCard;

        return Scaffold(
          backgroundColor: bgCol,
          appBar: _buildAppBar(context, surfaceCol, textCol, borderCol),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom:
                  context.getRSize(40) + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(
                  context,
                  surfaceCol,
                  textCol,
                  subtextCol,
                  borderCol,
                ),
                SizedBox(height: context.getRSize(16)),
                _buildBalanceSection(
                  context,
                  surfaceCol,
                  textCol,
                  subtextCol,
                  borderCol,
                ),
                SizedBox(height: context.getRSize(16)),
                _buildOrdersSection(
                  context,
                  cardCol,
                  textCol,
                  subtextCol,
                  borderCol,
                ),
                SizedBox(height: context.getRSize(16)),
                _buildPaymentsSection(
                  context,
                  cardCol,
                  textCol,
                  subtextCol,
                  borderCol,
                ),
                SizedBox(height: context.getRSize(16)),
                _buildCratesSection(
                  context,
                  surfaceCol,
                  cardCol,
                  textCol,
                  subtextCol,
                  borderCol,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Color surfaceCol,
    Color textCol,
    Color borderCol,
  ) {
    return AppBar(
      backgroundColor: surfaceCol,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: context.getRSize(20),
          color: textCol,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Customer Profile',
        style: TextStyle(
          fontSize: context.getRFontSize(18),
          fontWeight: FontWeight.w800,
          color: textCol,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: borderCol, height: 1),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color surfaceCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.getRSize(20)),
          decoration: BoxDecoration(
            color: surfaceCol,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: context.getRSize(40),
                backgroundColor: blueMain.withValues(alpha: 0.1),
                child: Text(
                  _customer!.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: blueMain,
                    fontSize: context.getRFontSize(32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: context.getRSize(16)),
              Text(
                _customer!.name,
                style: TextStyle(
                  fontSize: context.getRFontSize(22),
                  fontWeight: FontWeight.w800,
                  color: textCol,
                ),
              ),
              SizedBox(height: context.getRSize(8)),
              _infoRow(
                context,
                FontAwesomeIcons.locationDot,
                _customer!.addressText,
                textCol,
                subtextCol,
              ),
              SizedBox(height: context.getRSize(8)),
              _infoRow(
                context,
                FontAwesomeIcons.mapLocationDot,
                _customer!.googleMapsLocation,
                textCol,
                subtextCol,
              ),
              if (_customer!.phone != null && _customer!.phone!.isNotEmpty) ...[
                SizedBox(height: context.getRSize(8)),
                _infoRow(
                  context,
                  FontAwesomeIcons.phone,
                  _customer!.phone!,
                  textCol,
                  subtextCol,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: context.getRSize(12),
          right: context.getRSize(16),
          child: Text(
            'Joined on: ${DateFormat('MMM d, y').format(_customer!.createdAt)}',
            style: TextStyle(
              fontSize: context.getRFontSize(10),
              color: subtextCol.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String text,
    Color textCol,
    Color subtextCol,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: context.getRSize(14), color: subtextCol),
        SizedBox(width: context.getRSize(8)),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: context.getRFontSize(14),
              color: subtextCol,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSection(
    BuildContext context,
    Color surfaceCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    final isNegative = _customer!.customerWallet < 0;
    final balanceColor = isNegative ? danger : success;
    final formattedBalance = isNegative
        ? '-₦${fmtNumber(_customer!.customerWallet.abs().toInt())}'
        : '₦${fmtNumber(_customer!.customerWallet.toInt())}';

    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
          padding: EdgeInsets.all(context.getRSize(20)),
          decoration: BoxDecoration(
            color: surfaceCol,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(
                  fontSize: context.getRFontSize(14),
                  fontWeight: FontWeight.w600,
                  color: textCol,
                ),
              ),
              SizedBox(height: context.getRSize(8)),
              Text(
                formattedBalance,
                style: TextStyle(
                  fontSize: context.getRFontSize(32),
                  fontWeight: FontWeight.w800,
                  color: balanceColor,
                  letterSpacing: -1,
                ),
              ),
              if (_customer!.walletLimit != 0) ...[
                SizedBox(height: context.getRSize(4)),
                Text(
                  'Limit: -₦${fmtNumber(_customer!.walletLimit.abs().toInt())}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11),
                    color: subtextCol,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: context.getRSize(8),
          right: context.getRSize(24),
          child: IconButton(
            icon: Container(
              padding: EdgeInsets.all(context.getRSize(6)),
              decoration: BoxDecoration(
                color: blueMain.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.sliders,
                size: context.getRSize(12),
                color: blueMain,
              ),
            ),
            onPressed: () => _showSetWalletLimitDialog(context),
            tooltip: 'Set Wallet Limit',
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersSection(
    BuildContext context,
    Color cardCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orderService,
      builder: (context, ordersList, _) {
        final customerOrders =
            ordersList.where((o) => o.customerId == _customer!.id).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentOrders = customerOrders.take(3).toList();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, 'Orders / Receipts', textCol),
              SizedBox(height: context.getRSize(12)),
              if (customerOrders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(context.getRSize(24)),
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        FontAwesomeIcons.receipt,
                        size: context.getRSize(32),
                        color: subtextCol.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: context.getRSize(12)),
                      Text(
                        'No orders found for this customer.',
                        style: TextStyle(
                          fontSize: context.getRFontSize(14),
                          color: subtextCol,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: recentOrders.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: borderCol),
                    itemBuilder: (context, index) {
                      final order = recentOrders[index];
                      return InkWell(
                        onTap: () => _showReceiptModal(context, order),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(context.getRSize(16)),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(context.getRSize(10)),
                                decoration: BoxDecoration(
                                  color: blueMain.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  FontAwesomeIcons.fileInvoice,
                                  size: context.getRSize(14),
                                  color: blueMain,
                                ),
                              ),
                              SizedBox(width: context.getRSize(12)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${order.id.length > 5 ? order.id.substring(order.id.length - 5) : order.id}',
                                      style: TextStyle(
                                        fontSize: context.getRFontSize(15),
                                        fontWeight: FontWeight.w700,
                                        color: textCol,
                                      ),
                                    ),
                                    SizedBox(height: context.getRSize(4)),
                                    Text(
                                      '₦${NumberFormat('#,###').format(order.totalAmount)} • ${order.paymentMethod}',
                                      style: TextStyle(
                                        fontSize: context.getRFontSize(12),
                                        color: subtextCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, y').format(order.createdAt),
                                style: TextStyle(
                                  fontSize: context.getRFontSize(11),
                                  color: subtextCol,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (customerOrders.length > 3)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showAllOrdersModal(
                        context,
                        customerOrders,
                        cardCol,
                        textCol,
                        subtextCol,
                        borderCol,
                      ),
                      child: Text(
                        'View More',
                        style: TextStyle(
                          color: blueMain,
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(13),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAllOrdersModal(
    BuildContext context,
    List<Order> orders,
    Color bgCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String selectedFilter = 'All Time';
        final filters = ['Day', 'Week', 'Month', 'Year', 'All Time'];

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final now = DateTime.now();
            List<Order> filteredOrders = orders.where((o) {
              if (selectedFilter == 'All Time') return true;
              final diff = now.difference(o.createdAt);
              if (selectedFilter == 'Day') {
                return diff.inDays == 0 && now.day == o.createdAt.day;
              }
              if (selectedFilter == 'Week') return diff.inDays <= 7;
              if (selectedFilter == 'Month') return diff.inDays <= 30;
              if (selectedFilter == 'Year') return diff.inDays <= 365;
              return true;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).padding.bottom,
              ),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.85,
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        0,
                      ),
                      child: Center(
                        child: Container(
                          width: modalCtx.getRSize(40),
                          height: modalCtx.getRSize(4),
                          decoration: BoxDecoration(
                            color: borderCol,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(20)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: modalCtx.getRSize(20),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'All Orders',
                          style: TextStyle(
                            fontSize: modalCtx.getRFontSize(18),
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(16)),
                    SizedBox(
                      height: modalCtx.getRSize(36),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: modalCtx.getRSize(20),
                        ),
                        itemCount: filters.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(width: modalCtx.getRSize(8)),
                        itemBuilder: (context, index) {
                          final f = filters[index];
                          final isSelected = f == selectedFilter;
                          return FilterChip(
                            label: Text(
                              f,
                              style: TextStyle(
                                fontSize: context.getRFontSize(12),
                                color: isSelected ? Colors.white : textCol,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (val) {
                              setDialogState(() => selectedFilter = f);
                            },
                            selectedColor: blueMain,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : borderCol,
                              ),
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(16)),
                    Expanded(
                      child: filteredOrders.isEmpty
                          ? Center(
                              child: Text(
                                _getEmptyText(selectedFilter, 'orders'),
                                style: TextStyle(
                                  fontSize: modalCtx.getRFontSize(16),
                                  color: subtextCol,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                modalCtx.getRSize(20),
                                0,
                                modalCtx.getRSize(20),
                                modalCtx.getRSize(20),
                              ),
                              shrinkWrap: true,
                              itemCount: filteredOrders.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: borderCol),
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                return InkWell(
                                  onTap: () =>
                                      _showReceiptModal(context, order),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: context.getRSize(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            context.getRSize(10),
                                          ),
                                          decoration: BoxDecoration(
                                            color: blueMain.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            FontAwesomeIcons.fileInvoice,
                                            size: context.getRSize(14),
                                            color: blueMain,
                                          ),
                                        ),
                                        SizedBox(width: context.getRSize(12)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order #${order.id.length > 5 ? order.id.substring(order.id.length - 5) : order.id}',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(15),
                                                  fontWeight: FontWeight.w700,
                                                  color: textCol,
                                                ),
                                              ),
                                              SizedBox(
                                                height: context.getRSize(4),
                                              ),
                                              Text(
                                                '₦${NumberFormat('#,###').format(order.totalAmount)} • ${order.paymentMethod}',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(12),
                                                  color: subtextCol,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'MMM d, y',
                                          ).format(order.createdAt),
                                          style: TextStyle(
                                            fontSize: context.getRFontSize(11),
                                            color: subtextCol,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReceiptModal(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final bgCol = isDark ? dSurface : lSurface;
        final borderCol = isDark ? dBorder : lBorder;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).padding.bottom,
          ),
          child: Container(
            height: MediaQuery.of(modalCtx).size.height * 0.85,
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    modalCtx.getRSize(20),
                    modalCtx.getRSize(20),
                    modalCtx.getRSize(20),
                    0,
                  ),
                  child: Center(
                    child: Container(
                      width: modalCtx.getRSize(40),
                      height: modalCtx.getRSize(4),
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: modalCtx.getRSize(20)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(modalCtx.getRSize(20)),
                    child: ReceiptWidget(
                      orderId: order.id,
                      cart: order.items,
                      subtotal: order.subtotal,
                      crateDeposit: order.crateDeposit,
                      total: order.totalAmount,
                      paymentMethod: order.paymentMethod,
                      customerName: order.customerName,
                      customerAddress: _customer?.addressText,
                      customerPhone: _customer?.phone,
                      cashReceived: order.amountPaid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsSection(
    BuildContext context,
    Color cardCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    final recentPayments = _customer!.payments.reversed.take(3).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(context, 'Payments Made', textCol),
              TextButton.icon(
                onPressed: () => _showAddPaymentDialog(context),
                icon: Icon(
                  FontAwesomeIcons.plus,
                  size: context.getRSize(14),
                  color: blueMain,
                ),
                label: Text(
                  'Fund Wallet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(13),
                    color: blueMain,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: blueMain.withValues(alpha: 0.1),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(12),
                    vertical: context.getRSize(6),
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.getRSize(12)),
          if (_customer!.payments.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.getRSize(20)),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Text(
                'No payments recorded yet.',
                style: TextStyle(
                  fontSize: context.getRFontSize(14),
                  color: subtextCol,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: recentPayments.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: borderCol),
                itemBuilder: (context, index) {
                  final payment = recentPayments[index];
                  return Padding(
                    padding: EdgeInsets.all(context.getRSize(16)),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.getRSize(10)),
                          decoration: BoxDecoration(
                            color: success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FontAwesomeIcons.moneyBillWave,
                            size: context.getRSize(14),
                            color: success,
                          ),
                        ),
                        SizedBox(width: context.getRSize(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+₦${fmtNumber(payment.amount.toInt())}',
                                style: TextStyle(
                                  fontSize: context.getRFontSize(15),
                                  fontWeight: FontWeight.w700,
                                  color: textCol,
                                ),
                              ),
                              if (payment.note != null &&
                                  payment.note!.isNotEmpty) ...[
                                SizedBox(height: context.getRSize(2)),
                                Text(
                                  payment.note!,
                                  style: TextStyle(
                                    fontSize: context.getRFontSize(12),
                                    color: subtextCol,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          DateFormat(
                            'MMM d, y • H:mm',
                          ).format(payment.timestamp),
                          style: TextStyle(
                            fontSize: context.getRFontSize(11),
                            color: subtextCol,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_customer!.payments.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showAllPaymentsModal(
                    context,
                    _customer!.payments,
                    cardCol,
                    textCol,
                    subtextCol,
                    borderCol,
                  ),
                  child: Text(
                    'View More',
                    style: TextStyle(
                      color: blueMain,
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(13),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAllPaymentsModal(
    BuildContext context,
    List<Payment> payments,
    Color bgCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String selectedFilter = 'All Time';
        final filters = ['Day', 'Week', 'Month', 'Year', 'All Time'];

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final now = DateTime.now();
            final allPayments = payments.reversed.where((p) {
              if (selectedFilter == 'All Time') return true;
              final diff = now.difference(p.timestamp);
              if (selectedFilter == 'Day') {
                return diff.inDays == 0 && now.day == p.timestamp.day;
              }
              if (selectedFilter == 'Week') return diff.inDays <= 7;
              if (selectedFilter == 'Month') return diff.inDays <= 30;
              if (selectedFilter == 'Year') return diff.inDays <= 365;
              return true;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).padding.bottom,
              ),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.85,
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        0,
                      ),
                      child: Center(
                        child: Container(
                          width: modalCtx.getRSize(40),
                          height: modalCtx.getRSize(4),
                          decoration: BoxDecoration(
                            color: borderCol,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(20)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: modalCtx.getRSize(20),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'All Payments',
                          style: TextStyle(
                            fontSize: modalCtx.getRFontSize(18),
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(16)),
                    SizedBox(
                      height: modalCtx.getRSize(36),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: modalCtx.getRSize(20),
                        ),
                        itemCount: filters.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(width: modalCtx.getRSize(8)),
                        itemBuilder: (context, index) {
                          final f = filters[index];
                          final isSelected = f == selectedFilter;
                          return FilterChip(
                            label: Text(
                              f,
                              style: TextStyle(
                                fontSize: context.getRFontSize(12),
                                color: isSelected ? Colors.white : textCol,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (val) {
                              setDialogState(() => selectedFilter = f);
                            },
                            selectedColor: blueMain,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : borderCol,
                              ),
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(16)),
                    Expanded(
                      child: allPayments.isEmpty
                          ? Center(
                              child: Text(
                                _getEmptyText(selectedFilter, 'payments'),
                                style: TextStyle(
                                  fontSize: modalCtx.getRFontSize(16),
                                  color: subtextCol,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                modalCtx.getRSize(20),
                                0,
                                modalCtx.getRSize(20),
                                modalCtx.getRSize(20),
                              ),
                              shrinkWrap: true,
                              itemCount: allPayments.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: borderCol),
                              itemBuilder: (context, index) {
                                final payment = allPayments[index];
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.getRSize(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          context.getRSize(10),
                                        ),
                                        decoration: BoxDecoration(
                                          color: success.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FontAwesomeIcons.moneyBillWave,
                                          size: context.getRSize(14),
                                          color: success,
                                        ),
                                      ),
                                      SizedBox(width: context.getRSize(12)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '+₦${fmtNumber(payment.amount.toInt())}',
                                              style: TextStyle(
                                                fontSize: context.getRFontSize(
                                                  15,
                                                ),
                                                fontWeight: FontWeight.w700,
                                                color: textCol,
                                              ),
                                            ),
                                            if (payment.note != null &&
                                                payment.note!.isNotEmpty) ...[
                                              SizedBox(
                                                height: context.getRSize(2),
                                              ),
                                              Text(
                                                payment.note!,
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(12),
                                                  color: subtextCol,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM d, y • H:mm',
                                        ).format(payment.timestamp),
                                        style: TextStyle(
                                          fontSize: context.getRFontSize(11),
                                          color: subtextCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCratesSection(
    BuildContext context,
    Color surfaceCol,
    Color cardCol,
    Color textCol,
    Color subtextCol,
    Color borderCol,
  ) {
    final outstandingCrates = _customer!.emptyCratesBalance.entries
        .where((e) => e.value > 0)
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(context, 'Empty Crates Balance', textCol),
              TextButton.icon(
                onPressed: outstandingCrates.isEmpty
                    ? null
                    : () => _showReturnCratesDialog(context),
                icon: Icon(
                  FontAwesomeIcons.rotateLeft,
                  size: context.getRSize(14),
                ),
                label: Text(
                  'Return Crates',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(13),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: outstandingCrates.isEmpty
                      ? null
                      : blueMain.withValues(alpha: 0.1),
                  foregroundColor: outstandingCrates.isEmpty
                      ? subtextCol
                      : blueMain,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(12),
                    vertical: context.getRSize(6),
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.getRSize(12)),
          if (outstandingCrates.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.getRSize(20)),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Text(
                'No outstanding crates.',
                style: TextStyle(
                  fontSize: context.getRFontSize(14),
                  color: subtextCol,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: outstandingCrates.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: context.getRSize(8)),
              itemBuilder: (context, index) {
                final entry = outstandingCrates[index];
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(16),
                    vertical: context.getRSize(12),
                  ),
                  decoration: BoxDecoration(
                    color: surfaceCol,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key, // Crate group name
                        style: TextStyle(
                          fontSize: context.getRFontSize(15),
                          fontWeight: FontWeight.w600,
                          color: textCol,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.getRSize(12),
                          vertical: context.getRSize(4),
                        ),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.value} owed',
                          style: TextStyle(
                            fontSize: context.getRFontSize(13),
                            fontWeight: FontWeight.bold,
                            color: danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, Color textCol) {
    return Text(
      title,
      style: TextStyle(
        fontSize: context.getRFontSize(16),
        fontWeight: FontWeight.w800,
        color: textCol,
      ),
    );
  }

  // ── Modals ─────────────────────────────────────────────────────────────────

  void _showAddPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final bgCol = isDark ? dSurface : lSurface;
        final borderCol = isDark ? dBorder : lBorder;
        final cardCol = isDark ? dCard : lCard;
        final textCol = isDark ? dText : lText;
        final subtextCol = isDark ? dSubtext : lSubtext;

        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(modalCtx).viewInsets.bottom +
                MediaQuery.of(modalCtx).padding.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    modalCtx.getRSize(20),
                    modalCtx.getRSize(20),
                    modalCtx.getRSize(20),
                    0,
                  ),
                  child: Center(
                    child: Container(
                      width: modalCtx.getRSize(40),
                      height: modalCtx.getRSize(4),
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: modalCtx.getRSize(20)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: modalCtx.getRSize(20),
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Payment',
                            style: TextStyle(
                              fontSize: modalCtx.getRFontSize(18),
                              fontWeight: FontWeight.w800,
                              color: textCol,
                            ),
                          ),
                          SizedBox(height: modalCtx.getRSize(20)),
                          Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: modalCtx.getRFontSize(12),
                              fontWeight: FontWeight.w700,
                              color: subtextCol,
                            ),
                          ),
                          SizedBox(height: modalCtx.getRSize(8)),
                          TextFormField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [CurrencyInputFormatter()],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 5000',
                              hintStyle: TextStyle(color: subtextCol),
                              filled: true,
                              fillColor: cardCol,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: blueMain,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              prefixText: '₦ ',
                              prefixStyle: TextStyle(
                                color: textCol,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final parsed = parseCurrency(v);
                              if (parsed <= 0) {
                                return 'Invalid amount';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Note (Optional)',
                            style: TextStyle(
                              fontSize: modalCtx.getRFontSize(12),
                              fontWeight: FontWeight.w700,
                              color: subtextCol,
                            ),
                          ),
                          SizedBox(height: modalCtx.getRSize(8)),
                          TextFormField(
                            controller: noteCtrl,
                            style: TextStyle(fontSize: 14, color: textCol),
                            decoration: InputDecoration(
                              hintText: 'Payment note',
                              hintStyle: TextStyle(color: subtextCol),
                              filled: true,
                              fillColor: cardCol,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: blueMain,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueMain,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final amount = parseCurrency(amountCtrl.text);
                          final payment = Payment(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            amount: amount,
                            timestamp: DateTime.now(),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          customerService.addPayment(_customer!.id, payment);
                          Navigator.pop(modalCtx);
                        }
                      },
                      child: const Text(
                        'Confirm Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReturnCratesDialog(BuildContext context) {
    final List<Map<String, dynamic>> rows = [
      {'group': CrateGroup.nbPlc.label, 'qty': 0},
    ];
    final owableGroups = _customer!.emptyCratesBalance.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();
    if (owableGroups.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final bgCol = isDark ? dSurface : lSurface;
        final borderCol = isDark ? dBorder : lBorder;
        final cardCol = isDark ? dCard : lCard;
        final textCol = isDark ? dText : lText;
        final subtextCol = isDark ? dSubtext : lSubtext;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(modalCtx).viewInsets.bottom +
                    MediaQuery.of(modalCtx).padding.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        modalCtx.getRSize(20),
                        0,
                      ),
                      child: Center(
                        child: Container(
                          width: modalCtx.getRSize(40),
                          height: modalCtx.getRSize(4),
                          decoration: BoxDecoration(
                            color: borderCol,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(20)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: modalCtx.getRSize(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Return Empty Crates',
                              style: TextStyle(
                                fontSize: modalCtx.getRFontSize(18),
                                fontWeight: FontWeight.w800,
                                color: textCol,
                              ),
                            ),
                            SizedBox(height: modalCtx.getRSize(20)),
                            ...rows.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final rowData = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Crate Group',
                                            style: TextStyle(
                                              fontSize: modalCtx.getRFontSize(
                                                12,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              color: subtextCol,
                                            ),
                                          ),
                                          SizedBox(
                                            height: modalCtx.getRSize(8),
                                          ),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                owableGroups.contains(
                                                  rowData['group'],
                                                )
                                                ? rowData['group']
                                                : owableGroups.first,
                                            dropdownColor: cardCol,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textCol,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: cardCol,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                            ),
                                            items: owableGroups.map((g) {
                                              return DropdownMenuItem(
                                                value: g,
                                                child: Text(g),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDialogState(
                                                  () =>
                                                      rows[idx]['group'] = val,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Qty',
                                            style: TextStyle(
                                              fontSize: modalCtx.getRFontSize(
                                                12,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              color: subtextCol,
                                            ),
                                          ),
                                          SizedBox(
                                            height: modalCtx.getRSize(8),
                                          ),
                                          TextFormField(
                                            initialValue: rowData['qty']
                                                .toString(),
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: textCol,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: cardCol,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: blueMain,
                                                  width: 2,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                            ),
                                            onChanged: (val) {
                                              final parsed =
                                                  int.tryParse(val) ?? 0;
                                              rows[idx]['qty'] = parsed;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: modalCtx.getRSize(26),
                                        left: modalCtx.getRSize(4),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: danger,
                                        ),
                                        onPressed: rows.length > 1
                                            ? () => setDialogState(
                                                () => rows.removeAt(idx),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  rows.add({
                                    'group': owableGroups.first,
                                    'qty': 0,
                                  });
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.plus,
                                size: 14,
                                color: blueMain,
                              ),
                              label: Text(
                                'Add Row',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueMain,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: blueMain.withValues(
                                  alpha: 0.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueMain,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final returns = <String, int>{};
                            for (var r in rows) {
                              final g = r['group'] as String;
                              final q = r['qty'] as int;
                              if (q > 0) {
                                returns[g] = (returns[g] ?? 0) + q;
                              }
                            }
                            if (returns.isNotEmpty) {
                              customerService.updateEmptyCratesBalance(
                                _customer!.id,
                                returns,
                              );
                            }
                            Navigator.pop(modalCtx);
                          },
                          child: const Text(
                            'Confirm Return',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSetWalletLimitDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final surfaceCol = isDark ? dSurface : lSurface;
        final textCol = isDark ? dText : lText;
        final subtextCol = isDark ? dSubtext : lSubtext;
        final borderCol = isDark ? dBorder : lBorder;
        final cardCol = isDark ? dCard : lCard;

        final limitCtrl = TextEditingController(
          text: _customer!.walletLimit.abs().toStringAsFixed(0),
        );

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceCol,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              modalCtx.getRSize(20),
              modalCtx.getRSize(20),
              modalCtx.getRSize(20),
              modalCtx.getRSize(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: modalCtx.getRSize(40),
                    height: modalCtx.getRSize(4),
                    decoration: BoxDecoration(
                      color: borderCol,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: modalCtx.getRSize(24)),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(modalCtx.getRSize(10)),
                      decoration: BoxDecoration(
                        color: blueMain.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FontAwesomeIcons.sliders,
                        size: modalCtx.getRSize(16),
                        color: blueMain,
                      ),
                    ),
                    SizedBox(width: modalCtx.getRSize(14)),
                    Text(
                      'Wallet Debt Limit',
                      style: TextStyle(
                        fontSize: modalCtx.getRFontSize(18),
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: modalCtx.getRSize(12)),
                Text(
                  'Set the maximum amount this customer can owe. Use a positive number here (it will represent a negative debt limit).',
                  style: TextStyle(
                    fontSize: modalCtx.getRFontSize(13),
                    color: subtextCol,
                  ),
                ),
                SizedBox(height: modalCtx.getRSize(24)),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  style: TextStyle(
                    fontSize: modalCtx.getRFontSize(16),
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Maximum Debt Amount',
                    labelStyle: TextStyle(color: subtextCol),
                    hintText: 'e.g. 50,000',
                    prefixIcon: Icon(
                      FontAwesomeIcons.nairaSign,
                      size: modalCtx.getRSize(14),
                      color: subtextCol,
                    ),
                    filled: true,
                    fillColor: cardCol,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: modalCtx.getRSize(32)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final val = parseCurrency(limitCtrl.text);
                      // Limits are stored as negative (max debt)
                      customerService.updateWalletLimit(
                        _customer!.id,
                        -val.abs(),
                      );
                      Navigator.pop(modalCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: modalCtx.getRSize(16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Limit',
                      style: TextStyle(
                        fontSize: modalCtx.getRFontSize(16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/order_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../customers/data/services/customer_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lSurface;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        // 1. Daily Sales
        final today = DateTime.now();
        final completedOrders = orderService.getCompleted();
        final todaysOrders = completedOrders.where((o) {
          final t = o.completedAt ?? o.createdAt;
          return t.year == today.year &&
              t.month == today.month &&
              t.day == today.day;
        });
        final dailySales = todaysOrders.fold<double>(
          0,
          (sum, o) => sum + o.totalAmount,
        );

        // 2. Pending Orders
        final pendingOrdersCount = orderService.getPending().length;

        // 3. Total Stock Value (Phase 2 feature not present in this branch)
        var totalStockValue = 0.0;

        // 4. Customer Wallet Summary
        final customers = customerService.getAll();
        var totalDebt = 0.0;
        var totalCredit = 0.0;
        for (var c in customers) {
          if (c.customerWallet < 0) totalDebt += c.customerWallet.abs();
          if (c.customerWallet > 0) totalCredit += c.customerWallet;
        }

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _surface,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: _text),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text(
              'Dashboard',
              style: TextStyle(
                color: _text,
                fontSize: context.getRFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.getRSize(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Overview',
                    style: TextStyle(
                      fontSize: context.getRFontSize(20),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: context.getRSize(16)),

                  // Primary Metrics Grid
                  GridView.count(
                    crossAxisCount: context.isPhone ? 2 : 4,
                    crossAxisSpacing: context.getRSize(12),
                    mainAxisSpacing: context.getRSize(12),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.2,
                    children: [
                      _buildMetricCard(
                        'Today\'s Sales',
                        '₦${fmtNumber(dailySales.toInt())}',
                        FontAwesomeIcons.nairaSign,
                        success,
                      ),
                      _buildMetricCard(
                        'Pending Orders',
                        '$pendingOrdersCount',
                        FontAwesomeIcons.boxOpen,
                        const Color(0xFFF59E0B),
                      ),
                      _buildMetricCard(
                        'Total Stock Value',
                        '₦${fmtNumber(totalStockValue.toInt())}',
                        FontAwesomeIcons.layerGroup,
                        blueMain,
                      ),
                      _buildMetricCard(
                        'Current Expenses',
                        '₦0',
                        FontAwesomeIcons.arrowTrendDown,
                        const Color(0xFFF59E0B),
                      ),
                    ],
                  ),

                  SizedBox(height: context.getRSize(24)),
                  Text(
                    'Customer Balances',
                    style: TextStyle(
                      fontSize: context.getRFontSize(18),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: context.getRSize(12)),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceCard(
                          'Total Debt (Owed)',
                          totalDebt,
                          danger,
                        ),
                      ),
                      SizedBox(width: context.getRSize(12)),
                      Expanded(
                        child: _buildBalanceCard(
                          'Total Credit (Prepaid)',
                          totalCredit,
                          success,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.getRSize(24)),
                  Text(
                    'Top 3 Products (Mock)',
                    style: TextStyle(
                      fontSize: context.getRFontSize(18),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: context.getRSize(12)),
                  _buildTopProductsList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(context.getRSize(12)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: context.getRSize(20)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: context.getRFontSize(title.contains('Mock') ? 14 : 18),
              fontWeight: FontWeight.bold,
              color: _text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.getRSize(4)),
          Text(
            title,
            style: TextStyle(
              fontSize: context.getRFontSize(12),
              color: _subtext,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, double amount, Color color) {
    return Container(
      padding: EdgeInsets.all(context.getRSize(16)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: context.getRFontSize(12),
            ),
          ),
          SizedBox(height: context.getRSize(8)),
          Text(
            '₦${fmtNumber(amount.toInt())}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: context.getRFontSize(18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList() {
    // Just pulling first 3 inventory items as mock data for Top 3
    final topItems = kInventoryItems.take(3).toList();

    return Column(
      children: topItems.map((item) {
        return Container(
          margin: EdgeInsets.only(bottom: context.getRSize(10)),
          padding: EdgeInsets.all(context.getRSize(12)),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.getRSize(8)),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: context.getRSize(16),
                ),
              ),
              SizedBox(width: context.getRSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _text,
                        fontSize: context.getRFontSize(14),
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: _subtext,
                        fontSize: context.getRFontSize(12),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'High Sales', // Mock string
                style: TextStyle(
                  color: success,
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

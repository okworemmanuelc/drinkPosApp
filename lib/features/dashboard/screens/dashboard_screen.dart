import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../inventory/data/inventory_data.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/services/order_service.dart';
import '../../expenses/data/services/expense_service.dart';
import '../../customers/data/services/customer_service.dart';

final Color warning = Color(0xFFF59E0B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Day';
  final List<String> _periods = ['Day', 'Week', 'Month', 'Year', 'To Date'];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  bool _isDateInPeriod(DateTime date, String period) {
    final now = DateTime.now();
    final diff = now.difference(date);

    switch (period) {
      case 'Day':
        return diff.inDays == 0 && now.day == date.day;
      case 'Week':
        return diff.inDays <= 7;
      case 'Month':
        return diff.inDays <= 30;
      case 'Year':
        return diff.inDays <= 365;
      case 'To Date':
        return true;
      default:
        return true;
    }
  }

  double get _totalStockValue {
    return kInventoryItems.fold(0.0, (sum, item) {
      return sum + (item.totalStock * 5000); // Mock cost price of 5000 per unit
    });
  }

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'dashboard',
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: const MenuButton(),
        title: const AppBarHeader(
          icon: FontAwesomeIcons.chartLine,
          title: 'BrewFlow',
          subtitle: 'Business Overview',
        ),
        actions: [
          const NotificationBell(),
          SizedBox(width: context.getRSize(8)),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([orderService, expenseService, customerService]),
          builder: (context, _) {
            final orders = orderService.value;
            final expenses = expenseService.value;
            final customers = customerService.value;

            // Filter data by period
            final filteredOrders = orders.where((o) => _isDateInPeriod(o.createdAt, _selectedPeriod) && o.status == 'completed').toList();
            final filteredExpenses = expenses.where((e) => _isDateInPeriod(e.date, _selectedPeriod)).toList();

            // Calculate Metrics
            final totalSales = filteredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
            final totalExpenses = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
            final netProfit = totalSales - totalExpenses;
            final pendingOrdersCount = orders.where((o) => o.status == 'pending').length;

            final totalCredit = customers.fold(0.0, (sum, c) => sum + (c.customerWallet > 0 ? c.customerWallet : 0));
            final totalDebt = customers.fold(0.0, (sum, c) => sum + (c.customerWallet < 0 ? c.customerWallet.abs() : 0));

            return ListView(
              padding: EdgeInsets.all(context.spacingM),
              children: [
                _buildPeriodHeader(),
                SizedBox(height: context.spacingM),
                _buildMetricsGrid(
                  sales: totalSales,
                  pending: pendingOrdersCount,
                  profit: netProfit,
                  credit: totalCredit,
                  debt: totalDebt,
                ),
                SizedBox(height: context.spacingL),
                _buildExpenseTotal(totalExpenses),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: context.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            Text(
              'Analytics for the selected period',
              style: TextStyle(
                fontSize: context.getRFontSize(12),
                color: _subtext,
              ),
            ),
          ],
        ),
        _buildPeriodDropdown(),
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      width: context.getRSize(120),
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(12)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(context.radiusM),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isExpanded: true,
          alignment: AlignmentDirectional.bottomStart,
          menuMaxHeight: 350,
          borderRadius: BorderRadius.circular(12),
          icon: Padding(
            padding: EdgeInsets.only(left: context.getRSize(8)),
            child: Icon(
              FontAwesomeIcons.chevronDown,
              size: context.getRSize(10),
              color: blueMain,
            ),
          ),
          dropdownColor: _surface,
          items: _periods.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Text(
                p,
                style: TextStyle(
                  fontSize: context.getRFontSize(12),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedPeriod = val);
          },
        ),
      ),
    );
  }

  Widget _buildMetricsGrid({
    required double sales,
    required int pending,
    required double profit,
    required double credit,
    required double debt,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: context.spacingM,
      mainAxisSpacing: context.spacingM,
      childAspectRatio: 1.1,
      children: [
        _metricCard(
          '$_selectedPeriod Sales',
          formatCurrency(sales),
          FontAwesomeIcons.nairaSign,
          blueMain,
        ),
        _metricCard('Pending Orders', pending.toString(), FontAwesomeIcons.clock, warning),
        _metricCard(
          'Net Profit',
          formatCurrency(profit),
          FontAwesomeIcons.arrowTrendUp,
          profit >= 0 ? success : danger,
        ),
        _metricCard(
          'Total Loss',
          formatCurrency(0), // Mock for now
          FontAwesomeIcons.arrowTrendDown,
          danger,
        ),
        _metricCard(
          'Stock Value',
          formatCurrency(_totalStockValue),
          FontAwesomeIcons.boxesStacked,
          blueMain,
        ),
        _metricCard(
          'Customer Wallet',
          'Cr: ${formatCurrency(credit)}\nDr: ${formatCurrency(debt)}',
          FontAwesomeIcons.wallet,
          blueMain,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(context.spacingM),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(context.radiusL),
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
          Container(
            padding: EdgeInsets.all(context.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.radiusS),
            ),
            child: Icon(icon, color: color, size: context.getRSize(16)),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: context.getRFontSize(12),
              color: _subtext,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.getRSize(4)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: context.getRFontSize(18),
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTotal(double total) {
    return Container(
      padding: EdgeInsets.all(context.spacingL),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(context.radiusL),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.getRSize(12)),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              FontAwesomeIcons.fileInvoiceDollar,
              color: danger,
              size: context.getRSize(20),
            ),
          ),
          SizedBox(width: context.getRSize(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedPeriod Expenses',
                  style: TextStyle(
                    fontSize: context.getRFontSize(14),
                    color: _subtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatCurrency(total),
                  style: TextStyle(
                    fontSize: context.getRFontSize(24),
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

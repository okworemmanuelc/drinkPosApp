import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../inventory/data/inventory_data.dart';

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

  double get _totalStockValue {
    return kInventoryItems.fold(0.0, (sum, item) {
      // Mock price logic or lookup
      return sum + (item.totalStock * 5000); // Using 5000 as a base mock price
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
          _buildPeriodDropdown(),
          SizedBox(width: context.getRSize(16)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.getRSize(16)),
          children: [
            _buildMetricsGrid(),
            SizedBox(height: context.getRSize(24)),
            _buildExpenseTotal(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(12)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          icon: Icon(
            FontAwesomeIcons.chevronDown,
            size: context.getRSize(12),
            color: blueMain,
          ),
          dropdownColor: _surface,
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: context.getRSize(16),
      mainAxisSpacing: context.getRSize(16),
      childAspectRatio: 1.1,
      children: [
        _metricCard(
          'Daily Sales',
          formatCurrency(125000),
          FontAwesomeIcons.nairaSign,
          blueMain,
        ),
        _metricCard('Pending Orders', '12', FontAwesomeIcons.clock, warning),
        _metricCard(
          'Net Profit',
          formatCurrency(45000),
          FontAwesomeIcons.arrowTrendUp,
          success,
        ),
        _metricCard(
          'Total Loss',
          formatCurrency(5000),
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
          'Cr: ${formatCurrency(25000)}\nDr: ${formatCurrency(12000)}',
          FontAwesomeIcons.wallet,
          blueMain,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(context.getRSize(16)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
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
            padding: EdgeInsets.all(context.getRSize(8)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
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

  Widget _buildExpenseTotal() {
    return Container(
      padding: EdgeInsets.all(context.getRSize(20)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
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
                  'Expense Total',
                  style: TextStyle(
                    fontSize: context.getRFontSize(14),
                    color: _subtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatCurrency(8500),
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

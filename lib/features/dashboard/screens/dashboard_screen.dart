import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/models/order.dart';
import '../../../shared/services/order_service.dart';
import '../../../core/database/app_database.dart';
import '../../customers/data/models/customer.dart';
import '../../../shared/widgets/user_tips_modal.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/services/auth_service.dart';

const Color warning = Color(0xFFF59E0B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Day';
  final List<String> _periods = ['Day', 'Week', 'Month', 'Year', 'To Date'];

  // Warehouse filter (null = All)
  int? _selectedWarehouseId;
  List<WarehouseData> _warehouses = [];
  StreamSubscription? _warehousesSub;

  // True when the logged-in user is a manager locked to one warehouse
  bool _warehouseLocked = false;
  String _lockedWarehouseName = '';

  // Pro-tips hero visibility
  bool _showProTips = false;

  // DB-backed data
  List<Order> _allOrders = [];
  List<ExpenseData> _allExpenses = [];
  List<Customer> _customers = [];
  double _totalStockValue = 0;

  StreamSubscription? _ordersSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _customersSub;
  StreamSubscription? _inventorySub;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void initState() {
    super.initState();

    // Track login count to hide pro tips after first visit
    SharedPreferences.getInstance().then((prefs) {
      final count = (prefs.getInt('dashboard_visit_count') ?? 0) + 1;
      prefs.setInt('dashboard_visit_count', count);
      if (mounted) setState(() => _showProTips = count <= 1);
    });

    // Check if the logged-in user is a manager — lock dashboard to their warehouse
    final currentUser = authService.currentUser;
    final userTier = currentUser?.roleTier ?? 5;
    if (userTier == 4 && currentUser?.warehouseId != null) {
      _warehouseLocked = true;
      _selectedWarehouseId = currentUser!.warehouseId;
    }

    // Warehouses for the filter dropdown
    _warehousesSub = database.select(database.warehouses).watch().listen((wh) {
      if (mounted) {
        setState(() {
          _warehouses = wh;
          if (_warehouseLocked && _selectedWarehouseId != null) {
            _lockedWarehouseName = wh
                .where((w) => w.id == _selectedWarehouseId)
                .map((w) => w.name)
                .firstOrNull ?? '';
          }
        });
      }
    });

    _ordersSub = orderService.watchAllOrders().listen((orders) {
      if (mounted) setState(() => _allOrders = orders);
    });

    _expensesSub = database.expensesDao.watchAll().listen((expenses) {
      if (mounted) setState(() => _allExpenses = expenses);
    });

    _customersSub = database.customersDao.watchAllCustomers().listen((
      customers,
    ) {
      if (mounted) setState(() => _customers = customers.map((d) => Customer.fromDb(d)).toList());
    });

    // For managers locked to a warehouse, only count stock in that warehouse
    final stockStream = (_warehouseLocked && _selectedWarehouseId != null)
        ? database.inventoryDao.watchProductsByWarehouse(_selectedWarehouseId!)
        : database.inventoryDao.watchAllProductDatasWithStock();

    _inventorySub = stockStream.listen((items) {
      if (mounted) {
        setState(() {
          _totalStockValue = items.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.totalStock * item.product.sellingPriceKobo / 100.0),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _warehousesSub?.cancel();
    _ordersSub?.cancel();
    _expensesSub?.cancel();
    _customersSub?.cancel();
    _inventorySub?.cancel();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    // Filter by selected period
    final filteredOrders = _allOrders
        .where(
          (o) =>
              _isDateInPeriod(o.createdAt, _selectedPeriod) &&
              o.status == 'completed',
        )
        .toList();

    final filteredExpenses = _allExpenses
        .where((e) => _isDateInPeriod(e.timestamp, _selectedPeriod))
        .toList();

    // Metrics
    final totalSales = filteredOrders.fold<double>(
      0,
      (sum, o) => sum + o.totalAmount,
    );
    final totalExpenses = filteredExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amountKobo / 100.0,
    );
    final netProfit = totalSales - totalExpenses;
    final pendingOrdersCount = _allOrders
        .where((o) => o.status == 'pending')
        .length;

    final totalCredit = _customers.fold<double>(
      0,
      (sum, c) =>
          sum + (c.walletBalanceKobo > 0 ? c.walletBalanceKobo / 100.0 : 0),
    );
    final totalDebt = _customers.fold<double>(
      0,
      (sum, c) =>
          sum +
          (c.walletBalanceKobo < 0 ? c.walletBalanceKobo.abs() / 100.0 : 0),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => SharedScaffold(
        activeRoute: 'dashboard',
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: const MenuButton(),
          title: const AppBarHeader(
            icon: FontAwesomeIcons.chartLine,
            title: 'Ribaplus POS',
            subtitle: 'Business Overview',
          ),
          actions: [
            const NotificationBell(),
            SizedBox(width: context.getRSize(8)),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(context.spacingM),
          children: [
            if (_showProTips) ...[
              _buildQuickStartHero(),
              SizedBox(height: context.spacingL),
            ],
            _buildPeriodHeader(),
            SizedBox(height: context.spacingM),
            _buildMetricsList(
              sales: totalSales,
              pending: pendingOrdersCount,
              profit: netProfit,
              credit: totalCredit,
              debt: totalDebt,
              expenses: totalExpenses,
            ),
            SizedBox(height: context.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartHero() {
    return Container(
      padding: EdgeInsets.all(context.spacingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [blueMain, blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.radiusL),
        boxShadow: [
          BoxShadow(
            color: blueMain.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FontAwesomeIcons.rocket,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Welcome to Ribaplus POS!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Get started with our pro tips and master your beverage business in minutes.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => UserTipsModal.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: blueMain,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'View Pro Tips',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Overview',
          style: context.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        SizedBox(height: context.getRSize(2)),
        Text(
          'Analytics for the selected period',
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(12)),
        Row(
          children: [
            if (_warehouseLocked) ...[
              Flexible(child: _buildLockedWarehouseChip()),
              SizedBox(width: context.getRSize(8)),
            ] else if (_warehouses.isNotEmpty) ...[
              Flexible(child: _buildWarehouseDropdown()),
              SizedBox(width: context.getRSize(8)),
            ],
            Flexible(child: _buildPeriodDropdown()),
          ],
        ),
      ],
    );
  }

  Widget _buildLockedWarehouseChip() {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: context.getRSize(12)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warehouse_outlined, size: context.getRSize(14), color: blueMain),
          SizedBox(width: context.getRSize(6)),
          Text(
            _lockedWarehouseName.isEmpty ? 'My Warehouse' : _lockedWarehouseName,
            style: TextStyle(
              fontSize: context.getRFontSize(13),
              fontWeight: FontWeight.w600,
              color: blueMain,
            ),
          ),
          SizedBox(width: context.getRSize(4)),
          Icon(Icons.lock_outline, size: context.getRSize(12), color: _subtext),
        ],
      ),
    );
  }

  Widget _buildWarehouseDropdown() {
    return SizedBox(
      width: context.getRSize(160),
      child: AppDropdown<int?>(
        value: _selectedWarehouseId,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('All Warehouses')),
          ..._warehouses.map((wh) => DropdownMenuItem(value: wh.id, child: Text(wh.name))),
        ],
        onChanged: (v) => setState(() => _selectedWarehouseId = v),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return SizedBox(
      width: context.getRSize(140),
      child: AppDropdown<String>(
        value: _selectedPeriod,
        items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
        onChanged: (v) => setState(() => _selectedPeriod = v ?? 'Day'),
      ),
    );
  }

  Widget _buildMetricsList({
    required double sales,
    required int pending,
    required double profit,
    required double credit,
    required double debt,
    required double expenses,
  }) {
    return Column(
      children: [
        _robustMetricCard(
          label: 'Total Sales',
          value: formatCurrency(sales),
          subtitle: 'Generated from $_selectedPeriod transactions',
          icon: FontAwesomeIcons.nairaSign,
          color: blueMain,
          trend: sales > 0 ? 'Active' : 'No sales',
          isNeutral: true,
        ),
        SizedBox(height: context.spacingM),
        _robustMetricCard(
          label: 'Net Profit',
          value: formatCurrency(profit),
          subtitle: 'After all deductions',
          icon: FontAwesomeIcons.chartLine,
          color: profit >= 0 ? success : danger,
          trend: profit >= 0 ? 'Positive' : 'Negative',
          isPositive: profit >= 0,
        ),
        SizedBox(height: context.spacingM),
        _robustMetricCard(
          label: 'Pending Orders',
          value: pending.toString(),
          subtitle: 'Orders awaiting fulfillment',
          icon: FontAwesomeIcons.clock,
          color: warning,
          trend: pending > 0 ? 'Attention' : 'Clear',
          isNeutral: true,
        ),
        SizedBox(height: context.spacingM),
        _robustMetricCard(
          label: 'Total Expenses',
          value: formatCurrency(expenses),
          subtitle: 'Including operations & staff',
          icon: FontAwesomeIcons.fileInvoiceDollar,
          color: danger,
          trend: expenses > 0 ? 'Recorded' : 'None',
          isPositive: false,
          inverted: true,
        ),
        SizedBox(height: context.spacingM),
        _robustMetricCard(
          label: 'Stock Value',
          value: formatCurrency(_totalStockValue),
          subtitle: 'Estimated inventory worth',
          icon: FontAwesomeIcons.boxesStacked,
          color: blueMain,
          trend: 'Live',
          isNeutral: true,
        ),
        SizedBox(height: context.spacingM),
        _robustMetricCard(
          label: 'Customer Wallet',
          value: 'Cr: ${formatCurrency(credit)}',
          subtitle: 'Debt: ${formatCurrency(debt)}',
          icon: FontAwesomeIcons.wallet,
          color: blueMain,
          trend: 'Updated',
          isNeutral: true,
        ),
      ],
    );
  }

  Widget _robustMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
    bool isPositive = true,
    bool isNeutral = false,
    bool inverted = false,
  }) {
    final trendColor = isNeutral ? _subtext : (isPositive ? success : danger);
    final trendIcon = isNeutral
        ? FontAwesomeIcons.circleExclamation
        : (isPositive ? FontAwesomeIcons.arrowUp : FontAwesomeIcons.arrowDown);

    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          Container(
            width: context.getRSize(56),
            height: context.getRSize(56),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: context.getRSize(24)),
          ),
          SizedBox(width: context.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: context.getRFontSize(13),
                    color: _subtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.getRSize(2)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: context.getRFontSize(22),
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                SizedBox(height: context.getRSize(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: _subtext.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(10),
              vertical: context.getRSize(6),
            ),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendIcon, color: trendColor, size: context.getRSize(10)),
                SizedBox(width: context.getRSize(4)),
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: context.getRFontSize(11),
                    fontWeight: FontWeight.w800,
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


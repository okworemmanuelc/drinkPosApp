import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../data/models/payment.dart';
import '../data/services/payment_service.dart';
import '../widgets/add_payment_sheet.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/fluid_menu.dart';
import '../../inventory/data/models/supplier.dart';
import '../../inventory/data/services/supplier_service.dart';
import '../../inventory/screens/supplier_detail_screen.dart';
import '../../inventory/data/models/inventory_log.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/models/crate_group.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _periodFilter = 'This Month';
  String _supplierFilter = 'All';

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lSurface;

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
          drawer: const AppDrawer(activeRoute: 'supplier_accounts'),
          appBar: _buildAppBar(context),
          body: Column(
            children: [
              _buildTabBar(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentsTab(context),
                    _buildSuppliersTab(context),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [blueLight, blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              heroTag: 'payments_fab',
              onPressed: () => AddPaymentSheet.show(context),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: Icon(
                FontAwesomeIcons.plus,
                size: context.getRSize(16),
                color: Colors.white,
              ),
              label: Text(
                'Add Payment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(14),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
      leading: Builder(
        builder: (ctx) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 2.5,
                  width: context.getRSize(22),
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: context.getRSize(16),
                  decoration: BoxDecoration(
                    color: blueMain,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: context.getRSize(22),
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        const NotificationBell(),
        SizedBox(width: context.getRSize(8)),
      ],
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.getRSize(8)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blueLight, blueMain]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              FontAwesomeIcons.moneyBillWave,
              color: Colors.white,
              size: context.getRSize(16),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Supplier Accounts',
                    style: TextStyle(
                      fontSize: context.getRFontSize(18),
                      fontWeight: FontWeight.w800,
                      color: _text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Manage supplier payments',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11),
                    color: blueMain,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderArea(BuildContext context, double totalAmount) {
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(8),
        context.getRSize(16),
        context.getRSize(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Payments',
                style: TextStyle(
                  color: _subtext,
                  fontSize: context.getRFontSize(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: context.getRSize(4)),
              Text(
                formatCurrency(totalAmount),
                style: TextStyle(
                  color: _text,
                  fontSize: context.getRFontSize(24),
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
            FluidMenu<String>(
              value: _periodFilter,
              width: context.getRSize(130),
              items: [
                'Today',
                'This Week',
                'This Month',
                'This Year',
                'All Time',
              ].map((String val) {
                return FluidMenuItem<String>(value: val, label: val);
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _periodFilter = val;
                    _supplierFilter = 'All'; // Reset supplier filter on period change
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<String> suppliers) {
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
        vertical: context.getRSize(8),
        horizontal: context.getRSize(16),
      ),
      height: context.getRSize(56),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suppliers.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.getRSize(8)),
        itemBuilder: (context, index) {
          final sName = suppliers[index];
          final isSelected = sName == _supplierFilter;
          return FilterChip(
            label: Text(
              sName,
              style: TextStyle(
                fontSize: context.getRFontSize(12),
                color: isSelected ? Colors.white : _text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (val) {
              setState(() => _supplierFilter = sName);
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

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: _surface,
      child: TabBar(
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
          Tab(text: 'Payments'),
          Tab(text: 'Suppliers'),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(BuildContext context) {
    return ValueListenableBuilder<List<Payment>>(
      valueListenable: paymentService,
      builder: (context, payments, child) {
        final periodPayments = paymentService.getByPeriod(_periodFilter);

        // Compute unique suppliers for chips
        final Set<String> supplierNames = {};
        for (var p in periodPayments) {
          supplierNames.add(p.supplierName);
        }
        final supplierList = supplierNames.toList()..sort();
        supplierList.insert(0, 'All');

        // Apply supplier filter
        final filteredPayments = periodPayments.where((p) {
          if (_supplierFilter == 'All') return true;
          return p.supplierName == _supplierFilter;
        }).toList();

        filteredPayments.sort((a, b) => b.date.compareTo(a.date));

        final totalForPeriod = filteredPayments.fold(
          0.0,
          (sum, p) => sum + p.amount,
        );

        return Column(
          children: [
            _buildHeaderArea(context, totalForPeriod),
            if (supplierList.length > 1)
              _buildFilterChips(context, supplierList),
            Expanded(child: _buildPaymentsList(context, filteredPayments)),
          ],
        );
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(context.getRSize(16)),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain.withValues(alpha: 0.1),
                foregroundColor: blueMain,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: blueMain.withValues(alpha: 0.3)),
                ),
              ),
              icon: Icon(FontAwesomeIcons.plus, size: context.getRSize(16)),
              label: Text(
                'Add Supplier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(15),
                ),
              ),
              onPressed: _showAddSupplierDialog,
            ),
          ),
        ),
        Expanded(
          child: supplierService.getAll().isEmpty
              ? Center(
                  child: Text(
                    'No suppliers added yet',
                    style: TextStyle(color: _subtext),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.getRSize(16),
                    0,
                    context.getRSize(16),
                    context.getRSize(120),
                  ),
                  itemCount: supplierService.getAll().length,
                  itemBuilder: (_, i) {
                    final s = supplierService.getAll()[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierDetailScreen(supplier: s),
                        ),
                      ).then((_) => setState(() {})),
                      child: Container(
                        margin: EdgeInsets.only(bottom: context.getRSize(12)),
                        padding: EdgeInsets.all(context.getRSize(16)),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: context.getRSize(48),
                              height: context.getRSize(48),
                              decoration: BoxDecoration(
                                color: blueMain.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.buildingColumns,
                                color: blueMain,
                                size: context.getRSize(20),
                              ),
                            ),
                            SizedBox(width: context.getRSize(16)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: context.getRFontSize(16),
                                      color: _text,
                                    ),
                                  ),
                                  if (s.contactDetails.isNotEmpty) ...[
                                    SizedBox(height: context.getRSize(4)),
                                    Text(
                                      s.contactDetails,
                                      style: TextStyle(
                                        color: _subtext,
                                        fontSize: context.getRFontSize(13),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: _subtext,
                              size: context.getRSize(20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                Text(
                  'Add New Supplier',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                SizedBox(height: ctx.getRSize(4)),
                Text(
                  'Enter the company and contact details',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(13),
                    color: _subtext,
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                _inputField(
                  'Supplier / Company Name',
                  nameCtrl,
                  'e.g. SABMiller Nigeria',
                ),
                SizedBox(height: ctx.getRSize(16)),
                _inputField(
                  'Contact Details / Rep Info',
                  contactCtrl,
                  'e.g. John Doe, 08012345678',
                ),
                SizedBox(height: ctx.getRSize(32)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ctx.getRSize(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final newSupplier = Supplier(
                        id: 's${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        crateGroup: CrateGroup.nbPlc,
                        trackInventory: true,
                        contactDetails: contactCtrl.text.trim(),
                        amountPaid: 0.0,
                        supplierWallet: 0.0,
                      );
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: newSupplier.id,
                        itemName: newSupplier.name,
                        action: 'new_supplier',
                        previousValue: 0,
                        newValue: 0,
                        note: 'Supplier added: ${newSupplier.name}',
                      );
                      setState(() {
                        supplierService.addSupplier(newSupplier);
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ctx.getRFontSize(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            fontWeight: FontWeight.bold,
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(8)),
        TextField(
          controller: ctrl,
          style: TextStyle(color: _text, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _subtext.withValues(alpha: 0.5)),
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: blueMain),
            ),
            contentPadding: EdgeInsets.all(context.getRSize(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsList(BuildContext context, List<Payment> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.moneyCheckDollar,
              size: context.getRSize(48),
              color: _border,
            ),
            SizedBox(height: context.getRSize(16)),
            Text(
              'No payments found',
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
      padding: EdgeInsets.all(
        context.getRSize(16),
      ).copyWith(bottom: context.getRSize(100)),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final payment = list[index];
        return _PaymentCard(payment: payment);
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeNotifier.instance;
    final isDark = themeNotifier.value == ThemeMode.dark;
    final cardBg = isDark ? dCard : lSurface;
    final textCol = isDark ? dText : lText;
    final subtextCol = isDark ? dSubtext : lSubtext;
    final borderCol = isDark ? dBorder : lBorder;

    final dateStr = DateFormat('MMM d, y • h:mm a').format(payment.date);

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.getRSize(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(context.getRSize(10)),
              decoration: BoxDecoration(
                color: success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.arrowUpRightFromSquare,
                color: success,
                size: context.getRSize(14),
              ),
            ),
            SizedBox(width: context.getRSize(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          payment.supplierName,
                          style: TextStyle(
                            color: textCol,
                            fontWeight: FontWeight.bold,
                            fontSize: context.getRFontSize(15),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatCurrency(payment.amount),
                        style: TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(15),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.getRSize(6)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        payment.paymentMethod,
                        style: TextStyle(
                          color: subtextCol,
                          fontSize: context.getRFontSize(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: subtextCol,
                          fontSize: context.getRFontSize(12),
                        ),
                      ),
                    ],
                  ),
                  if (payment.referenceNumber != null &&
                      payment.referenceNumber!.isNotEmpty) ...[
                    SizedBox(height: context.getRSize(8)),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.hashtag,
                          size: context.getRSize(10),
                          color: subtextCol,
                        ),
                        SizedBox(width: context.getRSize(4)),
                        Text(
                          payment.referenceNumber!,
                          style: TextStyle(
                            color: subtextCol,
                            fontSize: context.getRFontSize(12),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} // Temporary themeNotifier instance

class ThemeNotifier {
  static final instance = themeNotifier;
}


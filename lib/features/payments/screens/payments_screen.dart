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

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _periodFilter = 'This Month';
  String _supplierFilter = 'All';

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: _bg,
          drawer: const AppDrawer(activeRoute: 'supplier_accounts'),
          appBar: _buildAppBar(context),
          body: ValueListenableBuilder<List<Payment>>(
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
                  Expanded(
                    child: _buildPaymentsList(context, filteredPayments),
                  ),
                ],
              );
            },
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.getRSize(12)),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _periodFilter,
                icon: Icon(
                  FontAwesomeIcons.chevronDown,
                  size: context.getRSize(12),
                  color: _text,
                ),
                dropdownColor: _surface,
                style: TextStyle(
                  color: _text,
                  fontSize: context.getRFontSize(13),
                  fontWeight: FontWeight.w600,
                ),
                items:
                    [
                      'Today',
                      'This Week',
                      'This Month',
                      'This Year',
                      'All Time',
                    ].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _periodFilter = val;
                      _supplierFilter =
                          'All'; // Reset supplier filter on period change
                    });
                  }
                },
              ),
            ),
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

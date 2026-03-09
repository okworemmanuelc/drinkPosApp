import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../customers/data/models/customer.dart';
import '../../customers/widgets/add_customer_sheet.dart';
import '../../../core/utils/stock_calculator.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../customers/data/services/customer_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/models/crate_group.dart';
import 'checkout_page.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double crateDeposit;
  final Customer? activeCustomer;
  final Function(Customer?) onCustomerChanged;

  const CartScreen({
    super.key,
    required this.cart,
    required this.crateDeposit,
    this.activeCustomer,
    required this.onCustomerChanged,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late double _crateDeposit;
  Customer? _activeCustomer;

  @override
  void initState() {
    super.initState();
    _crateDeposit = 0;
    _activeCustomer = widget.activeCustomer;
  }

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  void _showChangeCustomerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final customers = customerService.getAll().where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              final nameMatch = c.name.toLowerCase().contains(q);
              final phoneMatch = c.phone?.toLowerCase().contains(q) ?? false;
              return nameMatch || phoneMatch;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(modalCtx).size.height * 0.75,
                decoration: BoxDecoration(
                  color: _surface,
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
                        modalCtx.getRSize(14),
                        modalCtx.getRSize(20),
                        0,
                      ),
                      child: Center(
                        child: Container(
                          width: modalCtx.getRSize(40),
                          height: modalCtx.getRSize(4),
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: modalCtx.getRSize(16)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: modalCtx.getRSize(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Customer',
                            style: TextStyle(
                              fontSize: modalCtx.getRFontSize(18),
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  backgroundColor: blueMain.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  AddCustomerSheet.show(context);
                                },
                                icon: Icon(
                                  FontAwesomeIcons.userPlus,
                                  size: modalCtx.getRSize(14),
                                ),
                                label: Text(
                                  'New',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: modalCtx.getRFontSize(13),
                                  ),
                                ),
                              ),
                              SizedBox(width: modalCtx.getRSize(8)),
                              IconButton(
                                onPressed: () => Navigator.pop(modalCtx),
                                icon: Icon(Icons.close, color: _subtext),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: modalCtx.getRSize(20),
                        vertical: modalCtx.getRSize(8),
                      ),
                      child: TextField(
                        onChanged: (v) {
                          setDialogState(() {
                            searchQuery = v;
                          });
                        },
                        style: TextStyle(
                          color: _text,
                          fontSize: modalCtx.getRFontSize(14),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search customers...',
                          hintStyle: TextStyle(color: _subtext),
                          prefixIcon: Icon(
                            FontAwesomeIcons.magnifyingGlass,
                            size: modalCtx.getRSize(16),
                            color: _subtext,
                          ),
                          filled: true,
                          fillColor: _isDark ? dCard : lCard,
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: modalCtx.getRSize(16),
                            vertical: modalCtx.getRSize(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          modalCtx.getRSize(20),
                          0,
                          modalCtx.getRSize(20),
                          modalCtx.getRSize(20),
                        ),
                        children: [
                          _buildCustomerTile(null, modalCtx),
                          ...customers.map(
                            (c) => _buildCustomerTile(c, modalCtx),
                          ),
                        ],
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

  Widget _buildCustomerTile(Customer? customer, BuildContext modalCtx) {
    final bool isSelected = _activeCustomer?.id == customer?.id;
    final name = customer?.name ?? 'Walk-in Customer';
    final balance = customer?.customerWallet ?? 0.0;
    final isOwe = balance < 0;

    return InkWell(
      onTap: () {
        setState(() {
          _activeCustomer = customer;
        });
        widget.onCustomerChanged(customer);

        activityLogService.logAction(
          'Customer Assigned to Cart',
          'Cart assigned to $name',
          relatedEntityId: customer?.id,
          relatedEntityType: 'customer',
        );

        Navigator.pop(modalCtx);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: modalCtx.getRSize(12),
          horizontal: modalCtx.getRSize(8),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(modalCtx.getRSize(10)),
              decoration: BoxDecoration(
                color: blueMain.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                customer == null
                    ? FontAwesomeIcons.userTag
                    : FontAwesomeIcons.user,
                size: modalCtx.getRSize(16),
                color: blueMain,
              ),
            ),
            SizedBox(width: modalCtx.getRSize(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: modalCtx.getRFontSize(15),
                      color: _text,
                    ),
                  ),
                  if (customer != null) ...[
                    SizedBox(height: modalCtx.getRSize(4)),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.nairaSign,
                          size: modalCtx.getRSize(10),
                          color: balance == 0
                              ? success
                              : (isOwe ? danger : success),
                        ),
                        Text(
                          ' Bal: ₦${balance.abs().toStringAsFixed(0)} ${balance == 0 ? "clear" : (isOwe ? "overdue" : "credit")}',
                          style: TextStyle(
                            fontSize: modalCtx.getRFontSize(12),
                            color: balance == 0
                                ? success
                                : (isOwe ? danger : success),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                FontAwesomeIcons.circleCheck,
                color: blueMain,
                size: modalCtx.getRSize(18),
              ),
          ],
        ),
      ),
    );
  }

  void _editItem(BuildContext ctx, Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController(text: item['qty'].toString());
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          backgroundColor: _isDark ? dSurface : lSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: EdgeInsets.all(ctx.getRSize(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Quantity',
                style: TextStyle(
                  fontSize: ctx.getRFontSize(18),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              SizedBox(height: ctx.getRSize(4)),
              Text(
                item['name'],
                style: TextStyle(
                  fontSize: ctx.getRFontSize(13),
                  color: blueMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Row(
            children: [
              _qtyBtn(ctx, FontAwesomeIcons.minus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                if (v > 0.5) {
                  setD(() => qtyCtrl.text = (v - 0.5).toStringAsFixed(1));
                }
              }),
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(22),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: ctx.getRSize(16),
                    ),
                  ),
                ),
              ),
              _qtyBtn(ctx, FontAwesomeIcons.plus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                setD(() => qtyCtrl.text = (v + 0.5).toStringAsFixed(1));
              }),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() => widget.cart.remove(item));
                Navigator.pop(dCtx);
              },
              icon: Icon(
                FontAwesomeIcons.trash,
                color: danger,
                size: ctx.getRSize(15),
              ),
              label: const Text(
                'Remove',
                style: TextStyle(color: danger, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.getRSize(24),
                  vertical: ctx.getRSize(14),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(
                  () => item['qty'] = double.tryParse(qtyCtrl.text) ?? 1.0,
                );
                Navigator.pop(dCtx);
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.getRSize(46),
        height: context.getRSize(46),
        margin: EdgeInsets.symmetric(horizontal: context.getRSize(10)),
        decoration: BoxDecoration(
          color: blueMain.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: blueMain.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: context.getRSize(16), color: blueMain),
      ),
    );
  }

  void _showEditCrateDeposit() {
    final ctrl = TextEditingController(
      text: _crateDeposit == 0 ? '' : _crateDeposit.toInt().toString(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              context.getRSize(24),
              context.getRSize(16),
              context.getRSize(24),
              context.getRSize(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: context.getRSize(40),
                    height: context.getRSize(4),
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: context.getRSize(20)),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.getRSize(10)),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [blueLight, blueMain],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FontAwesomeIcons.beerMugEmpty,
                        size: context.getRSize(16),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: context.getRSize(12)),
                    Text(
                      'Crate Deposit',
                      style: TextStyle(
                        fontSize: context.getRFontSize(18),
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.getRSize(6)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter the deposit amount paid for crates',
                    style: TextStyle(
                      fontSize: context.getRFontSize(13),
                      color: _subtext,
                    ),
                  ),
                ),
                SizedBox(height: context.getRSize(20)),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  autofocus: true,
                  style: TextStyle(
                    fontSize: context.getRFontSize(20),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    prefixStyle: TextStyle(
                      fontSize: context.getRFontSize(20),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: context.getRFontSize(20),
                      fontWeight: FontWeight.bold,
                      color: _subtext.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: _isDark ? dCard : lCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(16),
                      vertical: context.getRSize(16),
                    ),
                  ),
                ),
                SizedBox(height: context.getRSize(24)),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(sheetCtx),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: context.getRSize(16),
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.getRFontSize(15),
                                color: _subtext,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.getRSize(12)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final val = parseCurrency(ctrl.text);
                          setState(() => _crateDeposit = val);
                          Navigator.pop(sheetCtx);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: context.getRSize(16),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blueLight, blueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: blueMain.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.getRFontSize(15),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool small = false,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(large ? 18 : 14),
            fontWeight: large ? FontWeight.bold : FontWeight.w600,
            color: large ? _text : _subtext,
          ),
        ),
        Text(
          '₦${fmtNumber(value.toInt())}',
          style: TextStyle(
            fontSize: context.getRFontSize(large ? 22 : 15),
            fontWeight: FontWeight.w800,
            color: large ? blueMain : _text,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.cart.sort((a, b) => b['qty'].compareTo(a['qty']));
    final sub = widget.cart.fold<double>(
      0.0,
      (s, i) =>
          s + stockValue((i['price'] as int).toDouble(), i['qty'] as double),
    );

    // ── Glass detection & crate deposit computation ──
    final glassItems = widget.cart
        .where((i) => i['category'] == 'Glass Crates')
        .toList();
    final hasGlass = glassItems.isNotEmpty;

    // Aggregate qty per CrateGroup
    final Map<CrateGroup, double> crateQtyMap = {};
    for (final item in glassItems) {
      final invItem = kInventoryItems.firstWhere(
        (inv) => inv.productName == item['name'],
        orElse: () => kInventoryItems.first,
      );
      final supplier = kSuppliers.firstWhere(
        (s) => s.id == invItem.supplierId,
        orElse: () => kSuppliers.first,
      );
      final group = supplier.crateGroup;
      crateQtyMap[group] = (crateQtyMap[group] ?? 0) + (item['qty'] as double);
    }

    // Compute deposit per group
    double computedDeposit = 0;
    final List<_CrateDepositLine> depositLines = [];
    for (final entry in crateQtyMap.entries) {
      final amount = entry.value * entry.key.deposit;
      computedDeposit += amount;
      depositLines.add(
        _CrateDepositLine(group: entry.key, qty: entry.value, amount: amount),
      );
    }

    // Customer crate balance offset
    double customerCrateCredit = 0;
    if (hasGlass && _activeCustomer != null) {
      for (final entry in crateQtyMap.entries) {
        final balKey = entry.key.label;
        final bal = _activeCustomer!.emptyCratesBalance[balKey] ?? 0;
        customerCrateCredit += bal * entry.key.deposit;
      }
    }

    // Total = Subtotal + manually entered crate deposit only
    final tot = sub + _crateDeposit;

    final customerName = _activeCustomer?.name ?? 'Walk-in Customer';
    final customerBalance = _activeCustomer?.customerWallet ?? 0.0;
    final isOwe = customerBalance < 0;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, child) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _text,
              size: context.getRSize(20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
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
                  FontAwesomeIcons.cartShopping,
                  color: Colors.white,
                  size: context.getRSize(16),
                ),
              ),
              SizedBox(width: context.getRSize(12)),
              Text(
                'Cart',
                style: TextStyle(
                  fontSize: context.getRFontSize(18),
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
            ],
          ),
          actions: [
            if (widget.cart.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() => widget.cart.clear());
                },
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: context.getRSize(16),
                    vertical: context.getRSize(10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(12),
                    vertical: context.getRSize(4),
                  ),
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.trashCan,
                        color: danger,
                        size: context.getRSize(13),
                      ),
                      SizedBox(width: context.getRSize(6)),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: danger,
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Fixed customer tab — full device width ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  context.getRSize(20),
                  context.getRSize(8),
                  context.getRSize(20),
                  context.getRSize(8),
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Container(
                  padding: EdgeInsets.all(context.getRSize(16)),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.getRSize(10)),
                        decoration: BoxDecoration(
                          color: blueMain.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _activeCustomer == null
                              ? FontAwesomeIcons.userTag
                              : FontAwesomeIcons.user,
                          size: context.getRSize(16),
                          color: blueMain,
                        ),
                      ),
                      SizedBox(width: context.getRSize(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.getRFontSize(14),
                                color: _text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.nairaSign,
                                  size: context.getRSize(11),
                                  color: customerBalance == 0
                                      ? success
                                      : (isOwe ? danger : success),
                                ),
                                Flexible(
                                  child: Text(
                                    ' Bal: ₦${customerBalance.abs().toStringAsFixed(0)} ${customerBalance == 0 ? "clear" : (isOwe ? "overdue" : "credit")}',
                                    style: TextStyle(
                                      fontSize: context.getRFontSize(12),
                                      color: customerBalance == 0
                                          ? success
                                          : (isOwe ? danger : success),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.getRSize(8)),
                      GestureDetector(
                        onTap: () => _showChangeCustomerModal(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.getRSize(12),
                            vertical: context.getRSize(6),
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: context.getRFontSize(12),
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Scrollable content: cart items + totals ──
              Expanded(
                child: widget.cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FontAwesomeIcons.cartArrowDown,
                              size: context.getRSize(48),
                              color: _border,
                            ),
                            SizedBox(height: context.getRSize(16)),
                            Text(
                              'Cart is empty',
                              style: TextStyle(
                                color: _subtext,
                                fontWeight: FontWeight.bold,
                                fontSize: context.getRFontSize(16),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // ── Cart item list ──
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: context.getRSize(20),
                                vertical: context.getRSize(8),
                              ),
                              itemCount: widget.cart.length,
                              separatorBuilder: (_, idx) =>
                                  SizedBox(height: context.getRSize(12)),
                              itemBuilder: (_, i) {
                                final item = widget.cart[i];
                                final Color c = item['color'] as Color;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _editItem(context, item),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      context.getRSize(12),
                                    ),
                                    decoration: BoxDecoration(
                                      color: _cardBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _border.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: context.getRSize(48),
                                          height: context.getRSize(48),
                                          decoration: BoxDecoration(
                                            color: c.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: c,
                                            size: context.getRSize(22),
                                          ),
                                        ),
                                        SizedBox(width: context.getRSize(14)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: context
                                                      .getRFontSize(15),
                                                  color: _text,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(
                                                height: context.getRSize(4),
                                              ),
                                              Text(
                                                '${item['qty'].toStringAsFixed(1)} × ₦${fmtNumber(item['price'])}',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(13),
                                                  color: _subtext,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '₦${fmtNumber(stockValue((item['price'] as int).toDouble(), item['qty'] as double).toInt())}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: context.getRFontSize(
                                                15,
                                              ),
                                              color: _text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // ── Totals section ──
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                context.getRSize(20),
                                context.getRSize(20),
                                context.getRSize(20),
                                context.getRSize(16),
                              ),
                              decoration: BoxDecoration(
                                color: _surface,
                                border: Border(top: BorderSide(color: _border)),
                              ),
                              child: Column(
                                children: [
                                  _totalRow('Subtotal', sub, small: true),
                                  SizedBox(height: context.getRSize(8)),
                                  if (hasGlass) ...[
                                    // ── Empty Crates section ──
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(
                                        context.getRSize(14),
                                      ),
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(
                                                  context.getRSize(8),
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          blueLight,
                                                          blueMain,
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  FontAwesomeIcons.beerMugEmpty,
                                                  size: context.getRSize(14),
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(
                                                width: context.getRSize(10),
                                              ),
                                              Text(
                                                'Empty Crates',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(14),
                                                  fontWeight: FontWeight.w800,
                                                  color: _text,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: context.getRSize(12),
                                          ),
                                          ...depositLines.map(
                                            (line) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: context.getRSize(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: context.getRSize(
                                                          8,
                                                        ),
                                                        height: context
                                                            .getRSize(8),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: line
                                                                  .group
                                                                  .color,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      SizedBox(
                                                        width: context.getRSize(
                                                          8,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${line.group.label}  ×${line.qty.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: context
                                                              .getRFontSize(13),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _subtext,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '₦${fmtNumber(line.amount.toInt())}',
                                                    style: TextStyle(
                                                      fontSize: context
                                                          .getRFontSize(13),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _text,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(height: 1, color: _border),
                                          SizedBox(height: context.getRSize(8)),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Required Deposit',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(13),
                                                  fontWeight: FontWeight.bold,
                                                  color: _text,
                                                ),
                                              ),
                                              Text(
                                                '₦${fmtNumber(computedDeposit.toInt())}',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(14),
                                                  fontWeight: FontWeight.w800,
                                                  color: blueMain,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (customerCrateCredit > 0) ...[
                                            SizedBox(
                                              height: context.getRSize(6),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Deposit Paid',
                                                  style: TextStyle(
                                                    fontSize: context
                                                        .getRFontSize(12),
                                                    fontWeight: FontWeight.w600,
                                                    color: success,
                                                  ),
                                                ),
                                                Text(
                                                  '-₦${fmtNumber(customerCrateCredit.toInt())}',
                                                  style: TextStyle(
                                                    fontSize: context
                                                        .getRFontSize(12),
                                                    fontWeight: FontWeight.bold,
                                                    color: success,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: context.getRSize(8)),
                                  ],
                                  // Crate Deposit tappable button — always visible
                                  GestureDetector(
                                    onTap: () => _showEditCrateDeposit(),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.getRSize(16),
                                        vertical: context.getRSize(14),
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            blueMain.withValues(alpha: 0.08),
                                            blueMain.withValues(alpha: 0.04),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: blueMain.withValues(
                                            alpha: 0.25,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(
                                                  context.getRSize(8),
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          blueLight,
                                                          blueMain,
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  FontAwesomeIcons.beerMugEmpty,
                                                  size: context.getRSize(13),
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(
                                                width: context.getRSize(10),
                                              ),
                                              Text(
                                                'Crate Deposit',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(14),
                                                  fontWeight: FontWeight.w700,
                                                  color: _text,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '₦${fmtNumber(_crateDeposit.toInt())}',
                                                style: TextStyle(
                                                  fontSize: context
                                                      .getRFontSize(15),
                                                  fontWeight: FontWeight.w800,
                                                  color: blueMain,
                                                ),
                                              ),
                                              SizedBox(
                                                width: context.getRSize(6),
                                              ),
                                              Icon(
                                                FontAwesomeIcons.penToSquare,
                                                size: context.getRSize(13),
                                                color: blueMain,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.getRSize(16)),
                                  Container(height: 1, color: _border),
                                  SizedBox(height: context.getRSize(16)),
                                  _totalRow('Total', tot, large: true),
                                  SizedBox(height: context.getRSize(24)),
                                  // ── Proceed to Checkout ──
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CheckoutPage(
                                            cart:
                                                List<Map<String, dynamic>>.from(
                                                  widget.cart,
                                                ),
                                            subtotal: sub,
                                            crateDeposit: _crateDeposit,
                                            total: tot,
                                            customer: _activeCustomer,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        vertical: context.getRSize(18),
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [blueLight, blueDark],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: blueMain.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            FontAwesomeIcons.checkToSlot,
                                            color: Colors.white,
                                            size: context.getRSize(18),
                                          ),
                                          SizedBox(width: context.getRSize(10)),
                                          Text(
                                            'Proceed to Checkout',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: context.getRFontSize(
                                                16,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrateDepositLine {
  final CrateGroup group;
  final double qty;
  final double amount;

  const _CrateDepositLine({
    required this.group,
    required this.qty,
    required this.amount,
  });
}

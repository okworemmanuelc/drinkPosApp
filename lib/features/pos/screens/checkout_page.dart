import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/models/order.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/services/order_service.dart';
import '../../../shared/widgets/receipt_widget.dart';
import '../../../core/utils/responsive.dart';
import '../services/receipt_builder.dart';
import '../../customers/data/models/customer.dart';
import '../../customers/data/models/payment.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../customers/data/services/customer_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../../core/utils/currency_input_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CheckoutPage — shown after "Proceed to Checkout" in the cart.
// ─────────────────────────────────────────────────────────────────────────────

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;
  final Customer? customer;

  const CheckoutPage({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
    this.customer,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

/// 3 payment methods:
/// - fullCash  → full amount paid now (cash or card), no balance added
/// - partialCash → partial payment, remainder added to customer balance
/// - credit    → full amount added to customer balance (disabled for walk-in)
enum PaymentType { fullCash, partialCash, credit }

class _CheckoutPageState extends State<CheckoutPage> {
  PaymentType _paymentType = PaymentType.fullCash;
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  bool _paymentConfirmed = false;

  // Computed on confirm — passed to receipt
  double _amountPaid = 0;
  String _currentOrderId = '';

  bool get _isWalkIn => widget.customer == null;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void dispose() {
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String get _paymentLabel {
    switch (_paymentType) {
      case PaymentType.fullCash:
        return 'Full Cash / Card';
      case PaymentType.partialCash:
        return 'Partial Cash / Card';
      case PaymentType.credit:
        return 'Credit Sale';
    }
  }

  String get _customerDisplayName =>
      widget.customer?.name ?? 'Walk-in Customer';

  double get _cashReceivedValue => parseCurrency(_cashReceivedCtrl.text);

  double get _dynamicNewBalance {
    final oldBalance = _isWalkIn ? 0.0 : widget.customer!.outstandingBalance;
    return oldBalance - widget.total + _cashReceivedValue;
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              size: context.getRSize(20),
              color: _text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _paymentConfirmed ? 'Receipt' : 'Checkout',
            style: TextStyle(
              fontSize: context.getRFontSize(18),
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: _paymentConfirmed ? _buildReceiptView() : _buildCheckoutForm(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECKOUT FORM
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCheckoutForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(20),
        context.getRSize(20),
        context.getRSize(40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order Summary ─────────────────────────────────────────────
          _sectionLabel('Order Summary'),
          SizedBox(height: context.getRSize(12)),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                ...widget.cart.map(_orderItemTile),
                Divider(height: 1, color: _border),
                _summaryRow('Subtotal', widget.subtotal),
                _summaryRow('Crate Deposit', widget.crateDeposit),
                Divider(height: 1, color: _border),
                _summaryRow('Total', widget.total, bold: true, accent: true),
              ],
            ),
          ),

          SizedBox(height: context.getRSize(28)),
          // ── Customer Info ─────────────────────────────────────────────
          _sectionLabel('Customer'),
          SizedBox(height: context.getRSize(12)),
          Container(
            padding: EdgeInsets.all(context.getRSize(14)),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.getRSize(10)),
                  decoration: BoxDecoration(
                    color: blueMain.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isWalkIn
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
                        _customerDisplayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(14),
                          color: _text,
                        ),
                      ),
                      if (!_isWalkIn) ...[
                        SizedBox(height: context.getRSize(2)),
                        Text(
                          'Balance: ₦${fmtNumber(widget.customer!.outstandingBalance.abs().toInt())} ${widget.customer!.outstandingBalance < 0
                              ? "(overdue)"
                              : widget.customer!.outstandingBalance > 0
                              ? "(credit)"
                              : "(clear)"}',
                          style: TextStyle(
                            fontSize: context.getRFontSize(12),
                            color: widget.customer!.outstandingBalance < 0
                                ? danger
                                : widget.customer!.outstandingBalance > 0
                                ? success
                                : _subtext,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.getRSize(28)),
          // ── Payment Method ────────────────────────────────────────────
          _sectionLabel('Payment Method'),
          SizedBox(height: context.getRSize(12)),

          // 1. Full Cash / Card
          _paymentOption(
            PaymentType.fullCash,
            'Full Cash / Card Payment',
            'Full amount paid now — no balance added',
            FontAwesomeIcons.moneyBill,
          ),

          // 2. Partial Cash / Card
          _paymentOption(
            PaymentType.partialCash,
            'Partial Cash / Card Payment',
            'Enter amount paid — remainder added to balance',
            FontAwesomeIcons.moneyBillTransfer,
          ),

          // Partial amount input + live remaining
          if (_paymentType == PaymentType.partialCash) ...[
            SizedBox(height: context.getRSize(16)),
            _inputField(
              'Amount Paid Now',
              _cashReceivedCtrl,
              '₦ Enter amount',
              isNumber: true,
            ),
            SizedBox(height: context.getRSize(10)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.getRSize(16),
                vertical: context.getRSize(12),
              ),
              decoration: BoxDecoration(
                color: blueMain.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blueMain.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining Balance',
                    style: TextStyle(
                      fontSize: context.getRFontSize(13),
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final newBalance = _dynamicNewBalance;
                      final isDebt = newBalance < 0;
                      final valText = isDebt
                          ? '-₦${fmtNumber(newBalance.abs().toInt())}'
                          : '+₦${fmtNumber(newBalance.toInt())}';
                      final valColor = isDebt ? Colors.amber.shade700 : success;

                      return Text(
                        newBalance == 0 ? '₦0' : valText,
                        style: TextStyle(
                          fontSize: context.getRFontSize(15),
                          fontWeight: FontWeight.w800,
                          color: valColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: context.getRSize(4)),
            if (!_isWalkIn)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(4)),
                child: Text(
                  'Remaining will be added to ${widget.customer!.name}\'s balance',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: _subtext,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (_isWalkIn)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(4)),
                child: Text(
                  'Remaining will appear on the receipt only (Walk-in)',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: _subtext,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],

          // 3. Credit Sale — disabled for walk-in
          _paymentOption(
            PaymentType.credit,
            'Register as Credit Sale',
            _isWalkIn
                ? 'Not available for Walk-in customers'
                : 'Full amount added to customer\'s outstanding balance',
            FontAwesomeIcons.fileInvoiceDollar,
            disabled: _isWalkIn,
          ),

          SizedBox(height: context.getRSize(32)),
          // ── Confirm button ────────────────────────────────────────────
          GestureDetector(
            onTap: _confirmPayment,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: context.getRSize(18)),
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
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.check,
                    color: Colors.white,
                    size: context.getRSize(18),
                  ),
                  SizedBox(width: context.getRSize(10)),
                  Text(
                    'Confirm Payment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.getRFontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirm payment logic ──────────────────────────────────────────────────
  void _confirmPayment() {
    // Validation
    if (_paymentType == PaymentType.partialCash && _cashReceivedValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the amount paid')),
      );
      return;
    }

    // Compute amounts
    double amountPaid;
    double orderRemaining;
    double extraPayment = 0;

    switch (_paymentType) {
      case PaymentType.fullCash:
        amountPaid = widget.total;
        orderRemaining = 0;
        break;
      case PaymentType.partialCash:
        if (_cashReceivedValue > widget.total) {
          amountPaid = widget.total;
          orderRemaining = 0;
          extraPayment = _cashReceivedValue - widget.total;
        } else {
          amountPaid = _cashReceivedValue;
          orderRemaining = widget.total - _cashReceivedValue;
        }
        break;
      case PaymentType.credit:
        amountPaid = 0;
        orderRemaining = widget.total;
        break;
    }

    // ── Inventory deduction ───────────────────────────────────────────
    for (final item in widget.cart) {
      final name = item['name'] as String;
      final qty = item['qty'] as double;
      final idx = kInventoryItems.indexWhere((inv) => inv.productName == name);
      if (idx != -1) {
        kInventoryItems[idx].stock -= qty;
        if (kInventoryItems[idx].stock < 0) {
          kInventoryItems[idx].stock = 0;
        }
      }
    }

    // ── Customer balance mutation ─────────────────────────────────────
    if (!_isWalkIn) {
      final customer = widget.customer!;

      // Deduct unpaid order amount from balance (reduces balance / adds debt)
      if (orderRemaining > 0) {
        final updatedCustomer = customer.copyWith(
          outstandingBalance: customer.outstandingBalance - orderRemaining,
        );
        customerService.updateCustomer(updatedCustomer);
      }

      // Add extra payment to ledger explicitly (adds to balance / pays off debt)
      if (extraPayment > 0) {
        final payment = Payment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: extraPayment,
          timestamp: DateTime.now(),
          note: 'Overpayment from checkout',
        );
        customerService.addPayment(customer.id, payment);
      }
    }

    // ── Create & store unified order ─────────────────────────────────────────
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final order = Order(
      id: orderId,
      customerId: widget.customer?.id,
      customerName: _customerDisplayName,
      customerAddress: widget.customer?.addressText ?? 'N/A',
      items: widget.cart,
      subtotal: widget.subtotal,
      crateDeposit: widget.crateDeposit,
      totalAmount: widget.total,
      amountPaid: amountPaid,
      balance: orderRemaining,
      paymentMethod: _paymentLabel,
      createdAt: DateTime.now(),
      status: 'pending',
    );
    orderService.addOrder(order);

    // ── Activity log ──────────────────────────────────────────────────
    activityLogService.logAction(
      'Sale Completed',
      'Order $orderId completed for $_customerDisplayName. '
          'Method: $_paymentLabel. '
          'Amount paid: ₦${fmtNumber(amountPaid.toInt())}. '
          'Balance: ₦${fmtNumber(orderRemaining.toInt())}',
      relatedEntityId: widget.customer?.id,
      relatedEntityType: 'customer',
    );
    activityLogService.logAction(
      'Order Dispatched',
      'Order $orderId for $_customerDisplayName added to pending deliveries',
      relatedEntityId: orderId,
      relatedEntityType: 'order',
    );

    // ── Store for receipt display ─────────────────────────────────────
    setState(() {
      _amountPaid = amountPaid;
      _paymentConfirmed = true;
      _currentOrderId = orderId;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECEIPT VIEW (shown after payment confirmed)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReceiptView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.getRSize(20)),
            child: Screenshot(
              controller: _screenshotCtrl,
              child: ReceiptWidget(
                orderId: _currentOrderId,
                cart: widget.cart,
                subtotal: widget.subtotal,
                crateDeposit: widget.crateDeposit,
                total: widget.total,
                paymentMethod: _paymentLabel,
                customerName: _customerDisplayName,
                customerAddress: widget.customer?.addressText,
                customerPhone: widget.customer?.phone,
                cashReceived: _paymentType == PaymentType.partialCash
                    ? _amountPaid
                    : null,
              ),
            ),
          ),
        ),
        _buildReceiptActions(),
      ],
    );
  }

  Widget _buildReceiptActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(16),
        context.getRSize(20),
        context.getRSize(32),
      ),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Text(
            'Receipt Options',
            style: TextStyle(
              fontSize: context.getRFontSize(16),
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          SizedBox(height: context.getRSize(16)),
          Row(
            children: [
              Expanded(
                child: _receiptButton(
                  'Print Receipt',
                  FontAwesomeIcons.print,
                  blueMain,
                  _printReceipt,
                ),
              ),
              SizedBox(width: context.getRSize(12)),
              Expanded(
                child: _receiptButton(
                  'Share Receipt',
                  FontAwesomeIcons.shareNodes,
                  success,
                  _shareReceipt,
                ),
              ),
            ],
          ),
          SizedBox(height: context.getRSize(12)),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Text(
                'Done — Back to POS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(14),
                  color: blueMain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.getRSize(14)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: context.getRSize(20), color: color),
            SizedBox(height: context.getRSize(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.getRFontSize(11),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Receipt actions ────────────────────────────────────────────────────────

  Future<void> _shareReceipt() async {
    try {
      final Uint8List? imageBytes = await _screenshotCtrl.capture(
        delay: const Duration(milliseconds: 50),
        pixelRatio: 3.0,
      );
      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture receipt image')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/brewflow_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'BrewFlow POS Receipt');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing receipt: $e')));
    }
  }

  Future<void> _printReceipt() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    final List<int> receiptBytes = await ThermalReceiptService.buildReceipt(
      orderId: _currentOrderId,
      cart: widget.cart,
      subtotal: widget.subtotal,
      crateDeposit: widget.crateDeposit,
      total: widget.total,
      paymentMethod: _paymentLabel,
      customerName: _customerDisplayName,
      customerAddress: widget.customer?.addressText,
      customerPhone: widget.customer?.phone,
      cashReceived: _paymentType == PaymentType.partialCash
          ? _amountPaid
          : null,
    );

    if (!mounted) return;

    // Check if already connected
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!mounted) return;

    if (isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Printing receipt...')));
      await PrintBluetoothThermal.writeBytes(receiptBytes);
      return;
    }

    // Try silent auto-connect to known printer
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    final targetPrinters = paired.where((d) {
      final name = d.name.toLowerCase();
      return name.contains('bluetooth_mobile_printer') ||
          name.contains('mp583');
    }).toList();

    if (targetPrinters.isNotEmpty) {
      final targetPrinter = targetPrinters.first;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecting to ${targetPrinter.name}...')),
        );
      }

      bool autoConnected = await PrintBluetoothThermal.connect(
        macPrinterAddress: targetPrinter.macAdress,
      );

      if (!mounted) return;

      if (autoConnected) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Printing receipt...')));
        await PrintBluetoothThermal.writeBytes(receiptBytes);
        return;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: FutureBuilder<List<BluetoothInfo>>(
            future: PrintBluetoothThermal.pairedBluetooths,
            builder: (c, snapshot) {
              final allDevices = snapshot.data ?? [];
              final devices = allDevices.where((d) {
                final n = d.name.toLowerCase();
                return n.contains('print') ||
                    n.contains('pos') ||
                    n.contains('therma') ||
                    n.contains('mtp') ||
                    n.contains('mp583');
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Select Receipt Printer',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: _border),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (devices.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No paired printers found',
                          style: TextStyle(color: _subtext),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        itemCount: devices.length,
                        itemBuilder: (_, i) {
                          final device = devices[i];
                          return ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(
                              device.name.isEmpty
                                  ? 'Unknown Device'
                                  : device.name,
                            ),
                            subtitle: Text(device.macAdress),
                            onTap: () async {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connecting to printer...'),
                                ),
                              );
                              bool connected =
                                  await PrintBluetoothThermal.connect(
                                    macPrinterAddress: device.macAdress,
                                  );
                              if (connected) {
                                await PrintBluetoothThermal.writeBytes(
                                  receiptBytes,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Print successful'),
                                  ),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to connect to printer.',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: context.getRFontSize(16),
        fontWeight: FontWeight.w800,
        color: _text,
      ),
    );
  }

  Widget _orderItemTile(Map<String, dynamic> item) {
    final lineTotal = ((item['price'] as int) * (item['qty'] as double))
        .toInt();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(10),
      ),
      child: Row(
        children: [
          Container(
            width: context.getRSize(38),
            height: context.getRSize(38),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'],
              size: context.getRSize(18),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                    color: _text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(item['qty'] as double).toStringAsFixed(1)} × ₦${fmtNumber(item['price'])}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: _subtext,
                  ),
                ),
              ],
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₦${fmtNumber(lineTotal)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(14),
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double value, {
    bool bold = false,
    bool accent = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.getRFontSize(bold ? 16 : 14),
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? _text : _subtext,
            ),
          ),
          Text(
            '₦${fmtNumber(value.toInt())}',
            style: TextStyle(
              fontSize: context.getRFontSize(bold ? 18 : 14),
              fontWeight: FontWeight.w800,
              color: accent ? blueMain : _text,
            ),
          ),
        ],
      ),
    );
  }

  /// Payment option tile.
  /// [disabled] is true for Credit Sale when walk-in customer.
  Widget _paymentOption(
    PaymentType type,
    String label,
    String subLabel,
    IconData icon, {
    bool disabled = false,
  }) {
    final active = !disabled && _paymentType == type;
    final effectiveColor = disabled ? _subtext : (active ? blueMain : _text);
    final iconColor = disabled ? _subtext : (active ? blueMain : _subtext);

    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _paymentType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: context.getRSize(10)),
        padding: EdgeInsets.all(context.getRSize(14)),
        decoration: BoxDecoration(
          color: disabled
              ? _border.withValues(alpha: 0.10)
              : active
              ? blueMain.withValues(alpha: 0.08)
              : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? _border.withValues(alpha: 0.4)
                : active
                ? blueMain
                : _border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: context.getRSize(42),
              height: context.getRSize(42),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: context.getRSize(18), color: iconColor),
            ),
            SizedBox(width: context.getRSize(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      fontSize: context.getRFontSize(14),
                      color: effectiveColor,
                    ),
                  ),
                  SizedBox(height: context.getRSize(2)),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: context.getRFontSize(12),
                      color: disabled ? danger : _subtext,
                      fontStyle: disabled ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Radio dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: context.getRSize(22),
              height: context.getRSize(22),
              decoration: BoxDecoration(
                color: active ? blueMain : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: disabled
                      ? _border.withValues(alpha: 0.4)
                      : active
                      ? blueMain
                      : _border,
                  width: 2,
                ),
              ),
              child: active
                  ? Icon(
                      Icons.check,
                      size: context.getRSize(14),
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(8)),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [CurrencyInputFormatter()] : null,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: context.getRFontSize(14), color: _text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _subtext),
            filled: true,
            fillColor: _cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: blueMain, width: 2),
            ),
            contentPadding: EdgeInsets.all(context.getRSize(16)),
          ),
        ),
      ],
    );
  }
}

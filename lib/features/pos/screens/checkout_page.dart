import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../services/receipt_builder.dart';
import '../../inventory/data/inventory_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CheckoutPage — shown after "Proceed to Checkout" in the cart.
// ─────────────────────────────────────────────────────────────────────────────

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;

  const CheckoutPage({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

enum PaymentType { fullCash, partialCash, card, credit }

class _CheckoutPageState extends State<CheckoutPage> {
  PaymentType _paymentType = PaymentType.fullCash;
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  bool _paymentConfirmed = false;

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
    _customerNameCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String get _paymentLabel {
    switch (_paymentType) {
      case PaymentType.fullCash:
        return 'Full Cash';
      case PaymentType.partialCash:
        return 'Partial Cash';
      case PaymentType.card:
        return 'Card';
      case PaymentType.credit:
        return 'Credit Sale';
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: context.getRSize(20),
              color: _text,
            ), // RESPONSIVE
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _paymentConfirmed ? 'Receipt' : 'Checkout',
            style: TextStyle(
              fontSize: context.getRFontSize(18), // RESPONSIVE
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
      ), // RESPONSIVE
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order Summary ─────────────────────────────────────────────
          _sectionLabel('Order Summary'),
          SizedBox(height: context.getRSize(12)), // RESPONSIVE
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

          SizedBox(height: context.getRSize(28)), // RESPONSIVE
          // ── Payment Type ──────────────────────────────────────────────
          _sectionLabel('Payment Method'),
          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          _paymentOption(
            PaymentType.fullCash,
            'Full Cash Payment',
            FontAwesomeIcons.moneyBill,
          ),
          _paymentOption(
            PaymentType.partialCash,
            'Partial Cash Payment',
            FontAwesomeIcons.moneyBillTransfer,
          ),
          _paymentOption(
            PaymentType.card,
            'Card Payment',
            FontAwesomeIcons.creditCard,
          ),
          _paymentOption(
            PaymentType.credit,
            'Register as Credit Sale',
            FontAwesomeIcons.fileInvoiceDollar,
          ),

          // ── Conditional fields ────────────────────────────────────────
          if (_paymentType == PaymentType.partialCash) ...[
            SizedBox(height: context.getRSize(16)), // RESPONSIVE
            _inputField(
              'Cash Received',
              _cashReceivedCtrl,
              '₦ Amount received in cash',
              isNumber: true,
            ),
            SizedBox(height: context.getRSize(8)), // RESPONSIVE
            Builder(
              builder: (_) {
                final cash = double.tryParse(_cashReceivedCtrl.text) ?? 0;
                final remainder = (widget.total - cash).clamp(0, widget.total);
                return Text(
                  'Remainder (card/credit): ₦${fmtNumber(remainder.toInt())}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(13), // RESPONSIVE
                    color: blueMain,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],

          if (_paymentType == PaymentType.credit) ...[
            SizedBox(height: context.getRSize(16)), // RESPONSIVE
            _inputField(
              'Customer Name / Account',
              _customerNameCtrl,
              'Enter customer name',
            ),
          ],

          SizedBox(height: context.getRSize(32)), // RESPONSIVE
          // ── Confirm button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: context.getRSize(18),
                ), // RESPONSIVE
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _confirmPayment,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.check,
                    size: context.getRSize(16),
                  ), // RESPONSIVE
                  SizedBox(width: context.getRSize(10)), // RESPONSIVE
                  Text(
                    'Confirm Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(16),
                    ), // RESPONSIVE
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment() {
    // basic validation
    if (_paymentType == PaymentType.credit &&
        _customerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a customer name')),
      );
      return;
    }
    if (_paymentType == PaymentType.partialCash &&
        (double.tryParse(_cashReceivedCtrl.text) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the cash amount received')),
      );
      return;
    }

    // Process Inventory Deduction
    for (var item in widget.cart) {
      final name = item['name'] as String;
      final qty = item['qty'] as double;

      final inventoryIndex = kInventoryItems.indexWhere(
        (inv) => inv.productName == name,
      );

      if (inventoryIndex != -1) {
        kInventoryItems[inventoryIndex].stock -= qty;
        if (kInventoryItems[inventoryIndex].stock < 0) {
          kInventoryItems[inventoryIndex].stock = 0; // Safeguard
        }
      }
    }

    setState(() => _paymentConfirmed = true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECEIPT VIEW (shown after payment confirmed)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReceiptView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.getRSize(20)), // RESPONSIVE
            child: Screenshot(
              controller: _screenshotCtrl,
              child: _ReceiptWidget(
                cart: widget.cart,
                subtotal: widget.subtotal,
                crateDeposit: widget.crateDeposit,
                total: widget.total,
                paymentMethod: _paymentLabel,
                customerName: _paymentType == PaymentType.credit
                    ? _customerNameCtrl.text.trim()
                    : null,
                cashReceived: _paymentType == PaymentType.partialCash
                    ? double.tryParse(_cashReceivedCtrl.text)
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
      ), // RESPONSIVE
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Text(
            'Receipt Options',
            style: TextStyle(
              fontSize: context.getRFontSize(16), // RESPONSIVE
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          SizedBox(height: context.getRSize(16)), // RESPONSIVE
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
              SizedBox(width: context.getRSize(12)), // RESPONSIVE
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
          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                // Pop back to POS screen
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Text(
                'Done — Back to POS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(14), // RESPONSIVE
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
        padding: EdgeInsets.symmetric(
          vertical: context.getRSize(14),
        ), // RESPONSIVE
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: context.getRSize(20), color: color), // RESPONSIVE
            SizedBox(height: context.getRSize(6)), // RESPONSIVE
            Text(
              label,
              style: TextStyle(
                fontSize: context.getRFontSize(11), // RESPONSIVE
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
    // 1. Request Bluetooth permissions first (required on modern Android)
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    // 2. Generate the raw ESC/POS bytes from our new builder
    final List<int> receiptBytes = await ThermalReceiptService.buildReceipt(
      cart: widget.cart,
      subtotal: widget.subtotal,
      crateDeposit: widget.crateDeposit,
      total: widget.total,
      paymentMethod: _paymentLabel,
      customerName: _paymentType == PaymentType.credit
          ? _customerNameCtrl.text.trim()
          : null,
      cashReceived: _paymentType == PaymentType.partialCash
          ? double.tryParse(_cashReceivedCtrl.text)
          : null,
    );

    // 3. Show bottom sheet to pick the paired Bluetooth Printer
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
              final devices = snapshot.data ?? [];
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

                              bool isConnected =
                                  await PrintBluetoothThermal.connect(
                                    macPrinterAddress: device.macAdress,
                                  );
                              if (isConnected) {
                                await PrintBluetoothThermal.writeBytes(
                                  receiptBytes,
                                );
                                await PrintBluetoothThermal.disconnect;

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
      ), // RESPONSIVE
    );
  }

  Widget _orderItemTile(Map<String, dynamic> item) {
    final lineTotal = ((item['price'] as int) * (item['qty'] as double))
        .toInt();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(10),
      ), // RESPONSIVE
      child: Row(
        children: [
          Container(
            width: context.getRSize(38), // RESPONSIVE
            height: context.getRSize(38), // RESPONSIVE
            decoration: BoxDecoration(
              color: (item['color'] as Color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'],
              size: context.getRSize(18), // RESPONSIVE
            ),
          ),
          SizedBox(width: context.getRSize(12)), // RESPONSIVE
          Expanded(
            // RESPONSIVE
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14), // RESPONSIVE
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
                  ), // RESPONSIVE
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
                fontSize: context.getRFontSize(14), // RESPONSIVE
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
      ), // RESPONSIVE
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.getRFontSize(bold ? 16 : 14), // RESPONSIVE
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? _text : _subtext,
            ),
          ),
          Text(
            '₦${fmtNumber(value.toInt())}',
            style: TextStyle(
              fontSize: context.getRFontSize(bold ? 18 : 14), // RESPONSIVE
              fontWeight: FontWeight.w800,
              color: accent ? blueMain : _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption(PaymentType type, String label, IconData icon) {
    final active = _paymentType == type;
    return GestureDetector(
      onTap: () => setState(() => _paymentType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: context.getRSize(10)), // RESPONSIVE
        padding: EdgeInsets.all(context.getRSize(14)), // RESPONSIVE
        decoration: BoxDecoration(
          color: active ? blueMain.withValues(alpha: 0.08) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? blueMain : _border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: context.getRSize(42), // RESPONSIVE
              height: context.getRSize(42), // RESPONSIVE
              decoration: BoxDecoration(
                color: (active ? blueMain : _subtext).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: context.getRSize(18),
                color: active ? blueMain : _subtext,
              ), // RESPONSIVE
            ),
            SizedBox(width: context.getRSize(14)), // RESPONSIVE
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                  fontSize: context.getRFontSize(14), // RESPONSIVE
                  color: active ? blueMain : _text,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: context.getRSize(22), // RESPONSIVE
              height: context.getRSize(22), // RESPONSIVE
              decoration: BoxDecoration(
                color: active ? blueMain : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? blueMain : _border,
                  width: 2,
                ),
              ),
              child: active
                  ? Icon(
                      Icons.check,
                      size: context.getRSize(14),
                      color: Colors.white,
                    ) // RESPONSIVE
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
            fontSize: context.getRFontSize(12), // RESPONSIVE
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        SizedBox(height: context.getRSize(8)), // RESPONSIVE
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            fontSize: context.getRFontSize(14),
            color: _text,
          ), // RESPONSIVE
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
            contentPadding: EdgeInsets.all(context.getRSize(16)), // RESPONSIVE
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ReceiptWidget — visually represents the receipt on screen to the user
// ═════════════════════════════════════════════════════════════════════════════

class _ReceiptWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;
  final String paymentMethod;
  final String? customerName;
  final double? cashReceived;

  const _ReceiptWidget({
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    this.cashReceived,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textCol = Color(0xFF0F172A);
    const sub = Color(0xFF64748B);
    const divCol = Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.getRSize(24)), // RESPONSIVE
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Text(
            'BrewFlow POS',
            style: TextStyle(
              fontSize: context.getRFontSize(20), // RESPONSIVE
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
          ),
          Text(
            'Sales Receipt',
            style: TextStyle(
              fontSize: context.getRFontSize(12),
              color: sub,
            ), // RESPONSIVE
          ),
          SizedBox(height: context.getRSize(4)), // RESPONSIVE
          Text(
            _formatDate(DateTime.now()),
            style: TextStyle(
              fontSize: context.getRFontSize(11),
              color: sub,
            ), // RESPONSIVE
          ),
          SizedBox(height: context.getRSize(16)), // RESPONSIVE
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          // Items
          ...cart.map((item) {
            final lineTotal = ((item['price'] as int) * (item['qty'] as double))
                .toInt();
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.getRSize(4),
              ), // RESPONSIVE
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']}  ×${(item['qty'] as double).toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: context.getRFontSize(13),
                        color: textCol,
                      ), // RESPONSIVE
                    ),
                  ),
                  Text(
                    '₦${fmtNumber(lineTotal)}',
                    style: TextStyle(
                      fontSize: context.getRFontSize(13), // RESPONSIVE
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                  ),
                ],
              ),
            );
          }),

          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          // Totals
          _infoRow(context, 'Subtotal', subtotal, sub),
          if (crateDeposit > 0) ...[
            SizedBox(height: context.getRSize(4)), // RESPONSIVE
            _infoRow(context, 'Crate Deposit', crateDeposit, sub),
          ],

          SizedBox(height: context.getRSize(12)), // RESPONSIVE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: context.getRFontSize(16), // RESPONSIVE
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              Text(
                '₦${fmtNumber(total.toInt())}',
                style: TextStyle(
                  fontSize: context.getRFontSize(18), // RESPONSIVE
                  fontWeight: FontWeight.w800,
                  color: blueMain,
                ),
              ),
            ],
          ),

          SizedBox(height: context.getRSize(16)), // RESPONSIVE
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(16)), // RESPONSIVE

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment: $paymentMethod',
              style: TextStyle(
                fontSize: context.getRFontSize(12),
                color: sub,
              ), // RESPONSIVE
            ),
          ),
          if (customerName != null && customerName!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Customer: $customerName',
                style: TextStyle(
                  fontSize: context.getRFontSize(12),
                  color: sub,
                ), // RESPONSIVE
              ),
            ),
          if (cashReceived != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cash Received: ₦${fmtNumber(cashReceived!.toInt())}',
                style: TextStyle(
                  fontSize: context.getRFontSize(12),
                  color: sub,
                ), // RESPONSIVE
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Remainder: ₦${fmtNumber((total - cashReceived!).clamp(0, total).toInt())}',
                style: TextStyle(
                  fontSize: context.getRFontSize(12),
                  color: sub,
                ), // RESPONSIVE
              ),
            ),
          ],

          SizedBox(height: context.getRSize(24)), // RESPONSIVE
          Text(
            'Thank you for your patronage!',
            style: TextStyle(
              fontSize: context.getRFontSize(13), // RESPONSIVE
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: sub,
            ),
          ),
          SizedBox(height: context.getRSize(4)), // RESPONSIVE
          Text(
            'Powered by BrewFlow',
            style: TextStyle(
              fontSize: context.getRFontSize(10),
              color: sub,
            ), // RESPONSIVE
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, double value, Color col) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.getRSize(2),
      ), // RESPONSIVE
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: context.getRFontSize(13), color: col),
          ), // RESPONSIVE
          Text(
            '₦${fmtNumber(value.toInt())}',
            style: TextStyle(
              fontSize: context.getRFontSize(13), // RESPONSIVE
              fontWeight: FontWeight.w600,
              color: col,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

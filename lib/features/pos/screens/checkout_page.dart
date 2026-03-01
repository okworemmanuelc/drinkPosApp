import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';

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
  bool _paymentConfirmed = false;

  final ScreenshotController _screenshotCtrl = ScreenshotController();

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
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: _text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _paymentConfirmed ? 'Receipt' : 'Checkout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          centerTitle: true,
        ),
        body: _paymentConfirmed ? _buildReceiptView() : _buildCheckoutForm(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECKOUT FORM
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCheckoutForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order Summary ─────────────────────────────────────────────
          _sectionLabel('Order Summary'),
          const SizedBox(height: 12),
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

          const SizedBox(height: 28),

          // ── Payment Type ──────────────────────────────────────────────
          _sectionLabel('Payment Method'),
          const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            _inputField(
              'Cash Received',
              _cashReceivedCtrl,
              '₦ Amount received in cash',
              isNumber: true,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final cash = double.tryParse(_cashReceivedCtrl.text) ?? 0;
                final remainder = (widget.total - cash).clamp(0, widget.total);
                return Text(
                  'Remainder (card/credit): ₦${fmtNumber(remainder.toInt())}',
                  style: TextStyle(
                    fontSize: 13,
                    color: blueMain,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],

          if (_paymentType == PaymentType.credit) ...[
            const SizedBox(height: 16),
            _inputField(
              'Customer Name / Account',
              _customerNameCtrl,
              'Enter customer name',
            ),
          ],

          const SizedBox(height: 32),

          // ── Confirm button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _confirmPayment,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(FontAwesomeIcons.check, size: 16),
                  SizedBox(width: 10),
                  Text(
                    'Confirm Payment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            padding: const EdgeInsets.all(20),
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
                isDark: _isDark,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Text(
            'Receipt Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _receiptButton(
                  'Print',
                  FontAwesomeIcons.print,
                  blueMain,
                  _printReceipt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _receiptButton(
                  'Share Image',
                  FontAwesomeIcons.image,
                  success,
                  _shareAsImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _receiptButton(
                  'Share PDF',
                  FontAwesomeIcons.filePdf,
                  danger,
                  _shareAsPdf,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  fontSize: 14,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

  Future<void> _printReceipt() async {
    // Uses the `printing` package which supports Bluetooth ePOS printers
    // and network printers. The user will pick a printer from the system
    // dialog. For direct Bluetooth ePOS printing, integrate esc_pos_bluetooth
    // as a future enhancement.
    await Printing.layoutPdf(
      onLayout: (format) => _generatePdfBytes(),
      name: 'BrewFlow_Receipt',
    );
  }

  Future<void> _shareAsImage() async {
    try {
      final image = await _screenshotCtrl.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
      );
      if (image == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/brewflow_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);

      await Share.shareXFiles([XFile(file.path)], text: 'BrewFlow POS Receipt');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share image: $e')));
      }
    }
  }

  Future<void> _shareAsPdf() async {
    try {
      final bytes = await _generatePdfBytes();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/brewflow_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: 'BrewFlow POS Receipt');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share PDF: $e')));
      }
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'BrewFlow POS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Receipt',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  DateTime.now().toString().substring(0, 19),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Divider(),
              // line items
              ...widget.cart.map((item) {
                final lineTotal =
                    ((item['price'] as int) * (item['qty'] as double)).toInt();
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['name']} x${(item['qty'] as double).toStringAsFixed(1)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Text(
                        'N${fmtNumber(lineTotal)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(),
              _pdfRow('Subtotal', widget.subtotal),
              _pdfRow('Crate Deposit', widget.crateDeposit),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'N${fmtNumber(widget.total.toInt())}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Payment: $_paymentLabel',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (_paymentType == PaymentType.credit)
                pw.Text(
                  'Customer: ${_customerNameCtrl.text}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (_paymentType == PaymentType.partialCash) ...[
                pw.Text(
                  'Cash: N${fmtNumber((double.tryParse(_cashReceivedCtrl.text) ?? 0).toInt())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Remainder: N${fmtNumber((widget.total - (double.tryParse(_cashReceivedCtrl.text) ?? 0)).clamp(0, widget.total).toInt())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Thank you for your patronage!',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            'N${fmtNumber(value.toInt())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text),
    );
  }

  Widget _orderItemTile(Map<String, dynamic> item) {
    final lineTotal = ((item['price'] as int) * (item['qty'] as double))
        .toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
                Text(
                  '${(item['qty'] as double).toStringAsFixed(1)} × ₦${fmtNumber(item['price'])}',
                  style: TextStyle(fontSize: 12, color: _subtext),
                ),
              ],
            ),
          ),
          Text(
            '₦${fmtNumber(lineTotal)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _text,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? _text : _subtext,
            ),
          ),
          Text(
            '₦${fmtNumber(value.toInt())}',
            style: TextStyle(
              fontSize: bold ? 18 : 14,
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? blueMain.withOpacity(0.08) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? blueMain : _border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (active ? blueMain : _subtext).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: active ? blueMain : _subtext),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: active ? blueMain : _text,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: active ? blueMain : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? blueMain : _border,
                  width: 2,
                ),
              ),
              child: active
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 14, color: _text),
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ReceiptWidget — a pure widget that renders a receipt card.
// Captured as an image by ScreenshotController.
// ═════════════════════════════════════════════════════════════════════════════

class _ReceiptWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;
  final String paymentMethod;
  final String? customerName;
  final double? cashReceived;
  final bool isDark;

  const _ReceiptWidget({
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    this.cashReceived,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Always render receipt on a white background for readability
    const bg = Colors.white;
    const textCol = Color(0xFF0F172A);
    const sub = Color(0xFF64748B);
    const divCol = Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          const Text(
            'BrewFlow POS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
          ),
          const Text(
            'Sales Receipt',
            style: TextStyle(fontSize: 12, color: sub),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(DateTime.now()),
            style: const TextStyle(fontSize: 11, color: sub),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: divCol),
          const SizedBox(height: 12),

          // Items
          ...cart.map((item) {
            final lineTotal = ((item['price'] as int) * (item['qty'] as double))
                .toInt();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']}  ×${(item['qty'] as double).toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 13, color: textCol),
                    ),
                  ),
                  Text(
                    '₦${fmtNumber(lineTotal)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          Container(height: 1, color: divCol),
          const SizedBox(height: 8),

          _row('Subtotal', subtotal, sub),
          _row('Crate Deposit', crateDeposit, sub),
          const SizedBox(height: 8),
          Container(height: 2, color: textCol.withOpacity(0.15)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              Text(
                '₦${fmtNumber(total.toInt())}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: blueMain,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: divCol),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment: $paymentMethod',
              style: const TextStyle(fontSize: 12, color: sub),
            ),
          ),
          if (customerName != null && customerName!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Customer: $customerName',
                style: const TextStyle(fontSize: 12, color: sub),
              ),
            ),
          if (cashReceived != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cash Received: ₦${fmtNumber(cashReceived!.toInt())}',
                style: const TextStyle(fontSize: 12, color: sub),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Remainder: ₦${fmtNumber((total - cashReceived!).clamp(0, total).toInt())}',
                style: const TextStyle(fontSize: 12, color: sub),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Thank you for your patronage!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: sub,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by BrewFlow',
            style: TextStyle(fontSize: 10, color: sub),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: col)),
          Text(
            '₦${fmtNumber(value.toInt())}',
            style: TextStyle(
              fontSize: 13,
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

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../../core/utils/number_format.dart'; // assuming fmtNumber is exported here

class ThermalReceiptService {
  /// Builds a byte array of ESC/POS commands formatted for 58mm (32 chars/line)
  static Future<List<int>> buildReceipt({
    required String orderId,
    required List<Map<String, dynamic>> cart,
    required double subtotal,
    required double crateDeposit,
    required double total,
    required String paymentMethod,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    double? cashReceived,
  }) async {
    // Generate profile for 58mm printer
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // --- 1. HEADER ---
    bytes += generator.text(
      'BREWFLOW POS',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'Wholesale Drinks & POS', // Optional tagline
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr(); // "--------------------------------"

    // --- 2. CUSTOMER & TRANSACTION DETAILS ---
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text(
        customerName,
        styles: const PosStyles(bold: true),
      );
      if (customerAddress != null && customerAddress.isNotEmpty) {
        bytes += generator.text(customerAddress);
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(customerPhone);
      }
    } else {
      bytes += generator.text(
        'Walk-in Customer',
        styles: const PosStyles(bold: true),
      );
    }

    // Add empty line spacing
    bytes += generator.text('');

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    bytes += generator.text('Order #$orderId');
    bytes += generator.text('Date: $dateStr');
    bytes += generator.hr();

    // --- 3. ITEMS LIST ---
    // Single line per item: [qty]x [product name]         [price]
    for (var item in cart) {
      final String name = item['name'].toString();
      final double qty = item['qty'] as double;
      final double price = (item['price'] as int).toDouble();
      final double lineTotal = qty * price;

      final String qtyStr = '${qty.toStringAsFixed(1)}x ';
      final String priceStr = 'N${fmtNumber(lineTotal.toInt())}';

      // Calculate max length for product name to fit in 32 characters
      int maxNameLen =
          32 - qtyStr.length - priceStr.length - 1; // 1 space minimum
      String nameStr = name;
      if (nameStr.length > maxNameLen) {
        nameStr = nameStr.substring(0, maxNameLen);
      }

      final String leftPart = '$qtyStr$nameStr';
      int spaceCount = 32 - leftPart.length - priceStr.length;
      if (spaceCount < 1) spaceCount = 1;

      final String spacing = ' ' * spaceCount;
      bytes += generator.text(
        '$leftPart$spacing$priceStr',
        styles: const PosStyles(bold: false, fontType: PosFontType.fontA),
      );
    }
    bytes += generator.hr();

    // --- 4. TOTALS SECTION ---
    bytes += _buildTwoColumnRow(
      generator,
      'Subtotal',
      'N${fmtNumber(subtotal.toInt())}',
    );

    if (crateDeposit > 0) {
      bytes += _buildTwoColumnRow(
        generator,
        'Crate Deposit',
        'N${fmtNumber(crateDeposit.toInt())}',
      );
    }
    bytes += generator.hr();

    // BIG TOTAL
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.left),
      ),
      PosColumn(
        text: 'N${fmtNumber(total.toInt())}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    bytes += generator.hr();

    // --- 5. PAYMENT SECTION ---
    bytes += generator.text(
      'Payment Method: $paymentMethod',
      styles: const PosStyles(bold: true),
    );

    if (cashReceived != null) {
      bytes += _buildTwoColumnRow(
        generator,
        'Amount Paid:',
        'N${fmtNumber(cashReceived.toInt())}',
      );
      final remainder = (total - cashReceived).clamp(0, total);
      bytes += _buildTwoColumnRow(
        generator,
        'Balance:',
        'N${fmtNumber(remainder.toInt())}',
      );
    } else if (paymentMethod == 'Register as Credit Sale') {
      bytes += _buildTwoColumnRow(generator, 'Amount Paid:', 'N0');
      bytes += _buildTwoColumnRow(
        generator,
        'Balance:',
        'N${fmtNumber(total.toInt())}',
      );
    } else {
      bytes += _buildTwoColumnRow(
        generator,
        'Amount Paid:',
        'N${fmtNumber(total.toInt())}',
      );
      bytes += _buildTwoColumnRow(generator, 'Balance:', 'N0');
    }

    bytes += generator.text('');

    // --- 6. BARCODE ---
    // ESC/POS Code 128 explicitly requires a subset control character to define the encoding type.
    // {B (123, 66) specifies Subset B which accepts all ascii chars.
    final List<int> barcodeData = [123, 66, ...orderId.codeUnits];
    bytes += generator.barcode(
      Barcode.code128(barcodeData),
      textPos: BarcodeText.none,
    );
    // Explicitly print the unformatted number below the barcode
    bytes += generator.text(
      orderId,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text('');

    // --- 7. FOOTER ---
    bytes += generator.text(
      'Goods received in good condition',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Powered by BrewFlow',
      styles: const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
      ),
    );

    // Minimal feed + cut to reduce paper waste
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Helper to create exactly 32-character lines for 58mm
  static List<int> _buildTwoColumnRow(
    Generator generator,
    String label,
    String value,
  ) {
    int spaceCount = 32 - label.length - value.length;
    if (spaceCount < 1) spaceCount = 1;
    final spacing = ' ' * spaceCount;
    return generator.text('$label$spacing$value');
  }
}

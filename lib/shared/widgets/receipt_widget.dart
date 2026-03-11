import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/number_format.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/stock_calculator.dart';

class ReceiptWidget extends StatelessWidget {
  final String orderId;
  final List<Map<String, dynamic>> cart;
  final double subtotal;
  final double crateDeposit;
  final double total;
  final String paymentMethod;
  final String? customerName;
  final String? customerAddress;
  final String? customerPhone;
  final double? cashReceived;
  final double? walletBalance;
  final DateTime? reprintDate;

  const ReceiptWidget({
    super.key,
    required this.orderId,
    required this.cart,
    required this.subtotal,
    required this.crateDeposit,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    this.customerAddress,
    this.customerPhone,
    this.cashReceived,
    this.walletBalance,
    this.reprintDate,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textCol = Color(0xFF0F172A);
    const sub = Color(0xFF64748B);
    const divCol = Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.getRSize(24)),
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
          if (reprintDate != null) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.getRSize(12),
                vertical: context.getRSize(4),
              ),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'REPRINTED',
                style: TextStyle(
                  fontSize: context.getRFontSize(16),
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(height: context.getRSize(12)),
          ],
          Text(
            'BrewFlow POS',
            style: TextStyle(
              fontSize: context.getRFontSize(20),
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
          ),
          Text(
            'Sales Receipt',
            style: TextStyle(fontSize: context.getRFontSize(12), color: sub),
          ),
          SizedBox(height: context.getRSize(16)),
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(12)),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              (customerName != null && customerName!.isNotEmpty)
                  ? [
                      customerName!,
                      if (customerAddress != null &&
                          customerAddress!.isNotEmpty)
                        customerAddress!,
                      if (customerPhone != null && customerPhone!.isNotEmpty)
                        customerPhone!,
                    ].join('\n')
                  : 'Walk-in Customer',
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.bold,
                color: textCol,
              ),
            ),
          ),
          SizedBox(height: context.getRSize(8)),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order: #$orderId',
                  style: TextStyle(fontSize: context.getRFontSize(12), color: sub),
                ),
                Text(
                  'Date: ${_formatDate(DateTime.now())}',
                  style: TextStyle(fontSize: context.getRFontSize(12), color: sub),
                ),
                if (reprintDate != null)
                  Text(
                    'Reprinted: ${_formatDate(reprintDate!)}',
                    style: TextStyle(
                      fontSize: context.getRFontSize(12),
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: context.getRSize(12)),
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(12)),

          ...cart.map((item) {
            final qty = (item['qty'] as num).toDouble();
            final price = (item['price'] as num).toInt();
            final lineTotal = stockValue(price.toDouble(), qty).toInt();
            return Padding(
              padding: EdgeInsets.symmetric(vertical: context.getRSize(4)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']}  ×${qty.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: context.getRFontSize(13),
                        color: textCol,
                      ),
                    ),
                  ),
                  Text(
                    formatCurrency(lineTotal),
                    style: TextStyle(
                      fontSize: context.getRFontSize(13),
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                  ),
                ],
              ),
            );
          }),

          SizedBox(height: context.getRSize(12)),
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(12)),

          _infoRow(context, 'Subtotal', subtotal, sub),
          if (crateDeposit > 0) ...[
            SizedBox(height: context.getRSize(4)),
            _infoRow(context, 'Crate Deposit', crateDeposit, sub),
          ],

          SizedBox(height: context.getRSize(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: context.getRFontSize(16),
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              Text(
                formatCurrency(total),
                style: TextStyle(
                  fontSize: context.getRFontSize(18),
                  fontWeight: FontWeight.w800,
                  color: blueMain,
                ),
              ),
            ],
          ),

          SizedBox(height: context.getRSize(16)),
          Container(height: 1, color: divCol),
          SizedBox(height: context.getRSize(16)),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment Method: $paymentMethod',
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          ),
          if (walletBalance != null) ...[
            SizedBox(height: context.getRSize(4)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Amount Paid: ${formatCurrency(cashReceived ?? total)}',
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  color: sub,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Wallet Balance: ${formatCurrency(walletBalance!)}',
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  color: walletBalance! < 0 ? danger : success,
                ),
              ),
            ),
          ] else ...[
            SizedBox(height: context.getRSize(4)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Amount Paid: ${formatCurrency(cashReceived ?? total)}',
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  color: sub,
                ),
              ),
            ),
          ],

          SizedBox(height: context.getRSize(24)),
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: orderId,
            width: context.getRSize(200),
            height: context.getRSize(60),
            style: TextStyle(
              fontSize: context.getRFontSize(12),
              color: textCol,
            ),
          ),
          SizedBox(height: context.getRSize(24)),

          Text(
            'Thank you for your patronage!',
            style: TextStyle(
              fontSize: context.getRFontSize(13),
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: sub,
            ),
          ),
          SizedBox(height: context.getRSize(4)),
          Text(
            'Powered by BrewFlow',
            style: TextStyle(fontSize: context.getRFontSize(10), color: sub),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, double value, Color col) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.getRSize(2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: context.getRFontSize(13), color: col),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              fontSize: context.getRFontSize(13),
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

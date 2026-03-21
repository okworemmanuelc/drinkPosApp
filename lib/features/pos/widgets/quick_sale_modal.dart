import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/cart_service.dart';

class QuickSaleModal extends StatefulWidget {
  final Color surfaceCol;
  final Color textCol;
  final Color subtextCol;
  final Color cardCol;
  final bool isDark;

  const QuickSaleModal({
    super.key,
    required this.surfaceCol,
    required this.textCol,
    required this.subtextCol,
    required this.cardCol,
    required this.isDark,
  });

  @override
  State<QuickSaleModal> createState() => _QuickSaleModalState();
}

class _QuickSaleModalState extends State<QuickSaleModal> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.surfaceCol,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Quick Sale ⚡',
        style: TextStyle(color: widget.textCol, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modalField(_nameCtrl, 'Item Name', FontAwesomeIcons.tag),
          SizedBox(height: context.getRSize(12)),
          _modalField(
            _qtyCtrl,
            'Quantity',
            FontAwesomeIcons.cubes,
            isNumber: true,
          ),
          SizedBox(height: context.getRSize(12)),
          _modalField(
            _priceCtrl,
            'Price Per Unit',
            FontAwesomeIcons.nairaSign,
            isNumber: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: widget.subtextCol,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(24),
              vertical: context.getRSize(12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: () {
            if (_nameCtrl.text.isNotEmpty &&
                _qtyCtrl.text.isNotEmpty &&
                _priceCtrl.text.isNotEmpty) {
              final product = {
                'name': _nameCtrl.text,
                'subtitle': 'Quick Sale',
                'price': double.tryParse(_priceCtrl.text) ?? 0.0,
                'icon': FontAwesomeIcons.bolt,
                'color': Theme.of(context).colorScheme.primary,
                'category': 'Other',
              };
              cartService.addItem(
                product,
                qty: double.tryParse(_qtyCtrl.text) ?? 1.0,
              );
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Item Name, Quantity, and Price are required.',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          child: const Text(
            'Send to Cart',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _modalField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(
        color: widget.textCol,
        fontSize: context.getRFontSize(14),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: widget.subtextCol),
        prefixIcon: Icon(
          icon,
          size: context.getRSize(16),
          color: widget.subtextCol,
        ),
        filled: true,
        fillColor: widget.cardCol,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.getRSize(16),
          vertical: context.getRSize(12),
        ),
      ),
    );
  }
}

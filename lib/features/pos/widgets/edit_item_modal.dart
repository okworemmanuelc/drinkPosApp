import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/widgets/app_input.dart';

class EditItemModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const EditItemModal({super.key, required this.item});

  @override
  ConsumerState<EditItemModal> createState() => _EditItemModalState();

  static Future<void> show(BuildContext context, Map<String, dynamic> item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditItemModal(item: item),
    );
  }
}

class _EditItemModalState extends ConsumerState<EditItemModal> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item['qty'].toString());

    // Auto-highlight text and show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _qtyCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyCtrl.text.length,
      );
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _updateQty(double delta) {
    final v = double.tryParse(_qtyCtrl.text) ?? 1.0;
    final newValue = (v + delta).clamp(0.5, 999.0);
    setState(() {
      _qtyCtrl.text = newValue.toStringAsFixed(
        newValue == newValue.toInt() ? 0 : 1,
      );
    });
    // Re-select text after manual update via buttons
    _qtyCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _qtyCtrl.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final border = t.dividerColor;
    final text = t.colorScheme.onSurface;
    final primary = t.colorScheme.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(24),
        context.getRSize(16),
        context.getRSize(24),
        context.bottomInset + context.getRSize(24),
      ),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: context.getRSize(40),
              height: context.getRSize(4),
              decoration: BoxDecoration(
                color: border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: context.getRSize(24)),

          // Header with Icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.getRSize(14)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.2),
                      primary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  FontAwesomeIcons.pills,
                  size: context.getRSize(20),
                  color: primary,
                ),
              ),
              SizedBox(width: context.getRSize(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Quantity',
                      style: TextStyle(
                        fontSize: context.getRFontSize(20),
                        fontWeight: FontWeight.w900,
                        color: text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.item['name'],
                      style: TextStyle(
                        fontSize: context.getRFontSize(14),
                        color: text.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: border.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    size: context.getRSize(20),
                    color: text.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.getRSize(32)),

          // Premium Quantity Selector
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(12),
              vertical: context.getRSize(12),
            ),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: border.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _qtyBtn(
                  FontAwesomeIcons.minus,
                  () => _updateQty(-1),
                  color: Colors.red,
                ),
                SizedBox(width: context.getRSize(12)),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: context.getRSize(4),
                    ),
                    decoration: BoxDecoration(
                      color: border.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AppInput(
                      controller: _qtyCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.getRFontSize(32),
                        fontWeight: FontWeight.w900,
                        color: primary,
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(width: context.getRSize(12)),
                _qtyBtn(
                  FontAwesomeIcons.plus,
                  () => _updateQty(1),
                  color: Colors.green,
                ),
              ],
            ),
          ),
          SizedBox(height: context.getRSize(12)),

          // Micro-adjustment chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _microAdjustChip('-0.5', () => _updateQty(-0.5)),
              SizedBox(width: context.getRSize(12)),
              _microAdjustChip('+0.5', () => _updateQty(0.5)),
            ],
          ),

          SizedBox(height: context.getRSize(40)),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Remove',
                  variant: AppButtonVariant.danger,
                  icon: FontAwesomeIcons.trashCan,
                  height: context.getRSize(56),
                  onPressed: () {
                    ref.read(cartProvider).removeItem(widget.item['name']);
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(width: context.getRSize(16)),
              Expanded(
                flex: 3,
                child: AppButton(
                  text: 'Save Changes',
                  variant: AppButtonVariant.primary,
                  height: context.getRSize(56),
                  onPressed: () {
                    final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
                    ref.read(cartProvider).updateQty(widget.item['name'], qty);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: context.getRSize(60),
          height: context.getRSize(60),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(icon, size: context.getRSize(20), color: color),
        ),
      ),
    );
  }

  Widget _microAdjustChip(String label, VoidCallback onTap) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(8),
          ),
          decoration: BoxDecoration(
            color: t.dividerColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: context.getRFontSize(13),
              fontWeight: FontWeight.w700,
              color: t.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

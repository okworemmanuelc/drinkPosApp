import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_notifier.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/stock_calculator.dart';
import '../../../../shared/services/activity_log_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/models/inventory_item.dart';
import '../../inventory/data/models/inventory_log.dart';
import '../../inventory/data/models/supplier.dart';
import '../../inventory/data/models/crate_group.dart';
import '../../inventory/data/services/supplier_service.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../pos/data/products_data.dart';
import '../data/models/delivery.dart';
import '../data/services/delivery_service.dart';

class ReceiveDeliverySheet extends StatefulWidget {
  const ReceiveDeliverySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReceiveDeliverySheet(),
    );
  }

  @override
  State<ReceiveDeliverySheet> createState() => _ReceiveDeliverySheetState();
}

class _DeliveryItemLine {
  final TextEditingController productCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();

  InventoryItem? selectedProduct;
  Supplier? selectedSupplier;
  CrateGroup? selectedCrateGroup;

  double get lineTotal {
    final price = parseCurrency(priceCtrl.text);
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    return stockValue(price, qty);
  }

  void dispose() {
    productCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _ReceiveDeliverySheetState extends State<ReceiveDeliverySheet> {
  final List<_DeliveryItemLine> _lines = [];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardBg => _isDark ? dCard : lCard;

  @override
  void initState() {
    super.initState();
    _addLine(null);
  }

  @override
  void dispose() {
    for (var l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine(ScrollController? scrollController) {
    setState(() {
      final line = _DeliveryItemLine();
      line.priceCtrl.addListener(_updateScope);
      line.qtyCtrl.addListener(_updateScope);
      _lines.add(line);
    });
    if (scrollController != null && scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _removeLine(int index) {
    if (_lines.length > 1) {
      setState(() {
        final l = _lines.removeAt(index);
        l.dispose();
      });
    }
  }

  void _updateScope() {
    setState(() {});
  }

  void _submit() {
    bool isValid = true;
    for (var l in _lines) {
      if (l.productCtrl.text.isEmpty ||
          (double.tryParse(l.qtyCtrl.text) ?? 0) <= 0) {
        isValid = false;
        break;
      }
    }
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill product name and quantity > 0'),
          backgroundColor: danger,
        ),
      );
      return;
    }

    final deliveryId = DateTime.now().millisecondsSinceEpoch.toString();
    double grandTotal = 0;
    double totalQty = 0;
    final List<DeliveryItem> deliveryItems = [];

    String mainSupplierName = 'Multiple Suppliers / Unknown';
    if (_lines.isNotEmpty && _lines.first.selectedSupplier != null) {
      mainSupplierName = _lines.first.selectedSupplier!.name;
    } else if (_lines.isNotEmpty) {
      mainSupplierName = '${_lines.first.productCtrl.text} Supplier';
    }

    for (var l in _lines) {
      final qty = double.tryParse(l.qtyCtrl.text) ?? 0;
      final price = parseCurrency(l.priceCtrl.text);
      final lineTot = stockValue(price, qty);
      grandTotal += lineTot;
      totalQty += qty;

      if (l.selectedProduct != null) {
        final warehouseId = l.selectedProduct!.warehouseStock.keys.isNotEmpty
            ? l.selectedProduct!.warehouseStock.keys.first
            : 'w1';

        final currentQty = l.selectedProduct!.warehouseStock[warehouseId] ?? 0.0;
        final newStockMap =
            Map<String, double>.from(l.selectedProduct!.warehouseStock);
        newStockMap[warehouseId] = currentQty + qty;
        l.selectedProduct!.warehouseStock = newStockMap;

        kInventoryLogs.add(
          InventoryLog(
            timestamp: DateTime.now(),
            user: 'System (Delivery)',
            itemId: l.selectedProduct!.id,
            itemName: l.selectedProduct!.productName,
            action: 'restock',
            previousValue: l.selectedProduct!.totalStock - qty,
            newValue: l.selectedProduct!.totalStock,
            note: 'Delivery Received',
          ),
        );

        final productData = kProducts.firstWhere(
          (p) => p['name'] == l.selectedProduct!.productName,
          orElse: () => <String, dynamic>{},
        );

        if (productData.isNotEmpty &&
            productData['category'] == 'Glass Crates') {
          final sup =
              l.selectedSupplier ??
              supplierService.getAll().firstWhere(
                (s) => s.id == l.selectedProduct!.supplierId,
                orElse: () =>
                    Supplier(id: '', name: '', crateGroup: CrateGroup.premium),
              );

          final cg = l.selectedCrateGroup ?? sup.crateGroup;
          final cStockIndex = kCrateStocks.indexWhere((c) => c.group == cg);
          if (cStockIndex != -1) {
            kCrateStocks[cStockIndex].available += qty;
          }
        }
      }

      deliveryItems.add(
        DeliveryItem(
          productId: l.selectedProduct?.id ?? '',
          productName: l.productCtrl.text,
          supplierName: l.selectedSupplier?.name ?? mainSupplierName,
          crateGroupLabel: l.selectedCrateGroup?.name,
          unitPrice: price,
          quantity: qty,
        ),
      );
    }

    final delivery = Delivery(
      id: deliveryId,
      supplierName: mainSupplierName,
      deliveredAt: DateTime.now(),
      items: deliveryItems,
      totalValue: grandTotal,
      status: 'confirmed',
    );

    deliveryService.addDelivery(delivery);

    activityLogService.logAction(
      "Delivery Received",
      "Delivery from $mainSupplierName — ${deliveryItems.length} item(s) received into inventory",
      relatedEntityId: delivery.id,
      relatedEntityType: "delivery",
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivery of ${totalQty.toInt()} items received.'),
        backgroundColor: success,
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.5, 0.9],
        builder: (context, scrollController) {
          double grandTotal = 0;
          for (var l in _lines) {
            grandTotal += l.lineTotal;
          }

          return GestureDetector(
            onTap: () {}, // Prevent tap from reaching the barrier
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.getRSize(12),
                    ),
                    child: Container(
                      width: context.getRSize(40),
                      height: context.getRSize(4),
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Receive Delivery',
                          style: TextStyle(
                            color: _text,
                            fontSize: context.getRFontSize(18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: _subtext),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _border),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.all(context.getRSize(16)),
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(context, index);
                      },
                    ),
                  ),
                  _buildSummaryBar(context, grandTotal, scrollController),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, int index) {
    final line = _lines[index];

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(16)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.getRSize(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item ${index + 1}',
                  style: TextStyle(
                    color: blueMain,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                  ),
                ),
                if (_lines.length > 1)
                  InkWell(
                    onTap: () => _removeLine(index),
                    child: Icon(
                      FontAwesomeIcons.circleMinus,
                      color: danger,
                      size: context.getRSize(18),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.getRSize(12)),

            // Product Name Autocomplete
            Text(
              'Product',
              style: TextStyle(
                color: _subtext,
                fontSize: context.getRFontSize(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.getRSize(6)),
            Autocomplete<InventoryItem>(
              displayStringForOption: (item) => item.productName,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<InventoryItem>.empty();
                }
                return kInventoryItems.where((InventoryItem item) {
                  return item.productName.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  );
                });
              },
              onSelected: (InventoryItem selection) {
                setState(() {
                  line.selectedProduct = selection;
                  line.productCtrl.text = selection.productName;

                  // Auto-fill supplier
                  final sup = supplierService.getAll().firstWhere(
                    (s) => s.id == selection.supplierId,
                    orElse: () => supplierService.getAll().isNotEmpty
                        ? supplierService.getAll().first
                        : Supplier(
                            id: '',
                            name: '',
                            crateGroup: CrateGroup.premium,
                          ),
                  );
                  line.selectedSupplier = sup;
                  line.selectedCrateGroup = sup.crateGroup;

                  // Pull wholesale price if available from products list
                  final productData = kProducts.firstWhere(
                    (p) => p['name'] == selection.productName,
                    orElse: () => <String, dynamic>{},
                  );
                  if (productData.isNotEmpty &&
                      productData['wholesale_price'] != null) {
                    line.priceCtrl.text = productData['wholesale_price']
                        .toString();
                  } else {
                    line.priceCtrl.text = '0.0';
                  }

                  if (line.qtyCtrl.text.isEmpty) {
                    line.qtyCtrl.text = '1';
                  }
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    if (controller.text.isEmpty &&
                        line.productCtrl.text.isNotEmpty) {
                      controller.text = line.productCtrl.text;
                    }
                    controller.addListener(() {
                      line.productCtrl.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDeco('Start typing product name...'),
                    );
                  },
            ),

            SizedBox(height: context.getRSize(16)),

            // Supplier Dropdown
            Text(
              'Supplier',
              style: TextStyle(
                color: _subtext,
                fontSize: context.getRFontSize(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.getRSize(6)),
            DropdownButton<Supplier>(
              value: line.selectedSupplier,
              isExpanded: true,
              underline: const SizedBox(),
              items: supplierService.getAll().map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name, style: TextStyle(color: _text)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  line.selectedSupplier = val;
                  if (val != null) {
                    line.selectedCrateGroup = val.crateGroup;
                  }
                });
              },
              dropdownColor: _surface,
            ),

            SizedBox(height: context.getRSize(16)),

            // Crate Group Dropdown
            Text(
              'Crate Group',
              style: TextStyle(
                color: _subtext,
                fontSize: context.getRFontSize(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.getRSize(6)),
            DropdownButton<CrateGroup>(
              value: line.selectedCrateGroup,
              isExpanded: true,
              underline: const SizedBox(),
              items: CrateGroup.values.map((cg) {
                return DropdownMenuItem(
                  value: cg,
                  child: Text(cg.name, style: TextStyle(color: _text)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  line.selectedCrateGroup = val;
                });
              },
              dropdownColor: _surface,
            ),

            SizedBox(height: context.getRSize(16)),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit Cost',
                        style: TextStyle(
                          color: _subtext,
                          fontSize: context.getRFontSize(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.getRSize(6)),
                      TextField(
                        controller: line.priceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _inputDeco('0.0'),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.getRSize(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qty',
                        style: TextStyle(
                          color: _subtext,
                          fontSize: context.getRFontSize(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.getRSize(6)),
                      TextField(
                        controller: line.qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _inputDeco('0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: context.getRSize(16)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Line Total: ${formatCurrency(line.lineTotal)}',
                style: TextStyle(
                  color: _subtext,
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, double grandTotal, ScrollController scrollController) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(12),
        context.getRSize(16),
        context.getRSize(24),
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        color: _subtext,
                        fontSize: context.getRFontSize(14),
                      ),
                    ),
                    Text(
                      formatCurrency(grandTotal),
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w800,
                        fontSize: context.getRFontSize(22),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _addLine(scrollController),
                  icon: Icon(FontAwesomeIcons.plus, size: context.getRSize(14)),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: blueMain,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(16),
                      vertical: context.getRSize(12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.getRSize(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueMain,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _submit,
                child: Text(
                  'Confirm Delivery',
                  style: TextStyle(
                    fontSize: context.getRFontSize(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

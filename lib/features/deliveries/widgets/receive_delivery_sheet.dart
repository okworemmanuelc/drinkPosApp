import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:reebaplus_pos/core/utils/number_format.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/shared/services/activity_log_service.dart';
import 'package:reebaplus_pos/features/inventory/data/models/supplier.dart';
import 'package:reebaplus_pos/features/inventory/data/services/supplier_service.dart';
import 'package:reebaplus_pos/shared/widgets/app_dropdown.dart';
import 'package:reebaplus_pos/features/deliveries/data/models/delivery.dart';
import 'package:reebaplus_pos/features/deliveries/data/services/delivery_service.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/widgets/app_input.dart';

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
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController retailPriceCtrl = TextEditingController();

  ProductData? selectedProduct;
  Supplier? selectedSupplier;
  String selectedCategory = 'Other';
  CrateGroupData? selectedCrateGroup;

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    return qty; // cost price not stored in ProductData; lineTotal = qty for now
  }

  void dispose() {
    productCtrl.dispose();
    qtyCtrl.dispose();
    retailPriceCtrl.dispose();
  }
}

class _ReceiveDeliverySheetState extends State<ReceiveDeliverySheet> {
  final List<_DeliveryItemLine> _lines = [];
  List<CrateGroupData> _crateGroups = [];
  List<ProductData> _allProducts = [];
  List<WarehouseData> _warehouses = [];
  WarehouseData? _selectedWarehouse;
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext =>
      Theme.of(context).textTheme.bodySmall?.color ??
      Theme.of(context).iconTheme.color!;
  Color get _border => Theme.of(context).dividerColor;
  Color get _cardBg => Theme.of(context).cardColor;

  @override
  void initState() {
    super.initState();
    _addLine(null);
    _loadCrateGroups();
    _loadProducts();
    _loadWarehouses();
  }

  Future<void> _loadCrateGroups() async {
    final groups = await database.inventoryDao.getAllCrateGroups();
    if (mounted) setState(() => _crateGroups = groups);
  }

  Future<void> _loadProducts() async {
    final products = await database.catalogDao
        .watchAvailableProductDatas()
        .first;
    if (mounted) setState(() => _allProducts = products);
  }

  Future<void> _loadWarehouses() async {
    final whs = await database.select(database.warehouses).get();
    if (mounted) {
      setState(() {
        _warehouses = whs;
        if (whs.isNotEmpty) _selectedWarehouse = whs.first;
      });
    }
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

  Future<void> _submit() async {
    // Validate warehouse
    if (_selectedWarehouse == null) {
      AppNotification.showError(
        context,
        'Please select a destination warehouse.',
      );
      return;
    }

    // Validate each line
    for (var l in _lines) {
      if (l.selectedProduct == null) {
        AppNotification.showError(
          context,
          'Select a product from the list for each item.',
        );
        return;
      }
      if ((double.tryParse(l.qtyCtrl.text) ?? 0) <= 0) {
        AppNotification.showError(
          context,
          'Quantity must be greater than 0 for each item.',
        );
        return;
      }
      if (l.selectedSupplier == null) {
        AppNotification.showError(
          context,
          'Please select a supplier for each item.',
        );
        return;
      }
      if (l.selectedCategory == 'Alcoholic' && l.selectedCrateGroup == null) {
        AppNotification.showError(
          context,
          'Select a Crate Company for Crate items.',
        );
        return;
      }
    }

    final deliveryId = DateTime.now().millisecondsSinceEpoch.toString();
    double totalQty = 0;
    final List<DeliveryItem> deliveryItems = [];

    String mainSupplierName = _lines.first.selectedSupplier!.name;

    for (var l in _lines) {
      final qty = (double.tryParse(l.qtyCtrl.text) ?? 0).toInt();
      totalQty += qty;

      // Update stock in the database
      await database.inventoryDao.adjustStock(
        l.selectedProduct!.id,
        _selectedWarehouse!.id,
        qty,
        'Delivery received',
        null,
      );

      // Auto-add empty crates for crate products
      if (l.selectedCrateGroup != null) {
        await database.inventoryDao.addEmptyCrates(
          l.selectedCrateGroup!.id,
          qty,
        );
      }

      deliveryItems.add(
        DeliveryItem(
          productId: l.selectedProduct!.id.toString(),
          productName: l.selectedProduct!.name,
          supplierName: l.selectedSupplier!.name,
          crateGroupLabel: l.selectedCrateGroup?.name,
          unitPrice: 0,
          quantity: qty.toDouble(),
        ),
      );
    }

    final delivery = Delivery(
      id: deliveryId,
      supplierName: mainSupplierName,
      deliveredAt: DateTime.now(),
      items: deliveryItems,
      totalValue: 0,
      status: 'confirmed',
    );

    deliveryService.addDelivery(delivery);

    await activityLogService.logAction(
      "Delivery Received",
      "Delivery from $mainSupplierName to ${_selectedWarehouse!.name} — ${deliveryItems.length} item(s), ${totalQty.toInt()} units added to stock",
      relatedEntityId: delivery.id,
      relatedEntityType: "delivery",
    );

    if (!mounted) return;

    Navigator.pop(context);
    AppNotification.showSuccess(
      context,
      '${totalQty.toInt()} units added to ${_selectedWarehouse!.name}.',
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
    bool isAutocomplete = false,
    _DeliveryItemLine? line,
  }) {
    if (isAutocomplete && line != null) {
      return Autocomplete<ProductData>(
        displayStringForOption: (p) => p.name,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<ProductData>.empty();
          }
          final q = textEditingValue.text.toLowerCase();
          return _allProducts.where((p) => p.name.toLowerCase().contains(q));
        },
        onSelected: (ProductData selection) {
          setState(() {
            line.selectedProduct = selection;
            line.productCtrl.text = selection.name;
            line.selectedCategory = 'Other';
            line.retailPriceCtrl.text = (selection.retailPriceKobo / 100)
                .round()
                .toString();

            if (selection.crateGroupId != null) {
              final match = _crateGroups
                  .where((cg) => cg.id == selection.crateGroupId)
                  .firstOrNull;
              line.selectedCrateGroup = match;
            } else {
              line.selectedCrateGroup = null;
            }

            if (line.qtyCtrl.text.isEmpty) {
              line.qtyCtrl.text = '1';
            }
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          if (controller.text.isEmpty && line.productCtrl.text.isNotEmpty) {
            controller.text = line.productCtrl.text;
          }
          controller.addListener(() {
            line.productCtrl.text = controller.text;
          });
          return AppInput(
            controller: controller,
            focusNode: focusNode,
            onFieldSubmitted: (_) => onEditingComplete(),
            labelText: label,
            hintText: hint,
            fillColor: _cardBg,
          );
        },
      );
    }

    return AppInput(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      labelText: label,
      hintText: hint,
      fillColor: _cardBg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.5, 0.8, 0.9],
        builder: (context, scrollController) {
          double grandTotal = 0;
          for (var l in _lines) {
            grandTotal += l.lineTotal;
          }

          return GestureDetector(
            onTap: () {}, // Prevent tap from reaching the barrier
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.getRSize(20),
                      context.getRSize(20),
                      context.getRSize(20),
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          'Receive Delivery',
                          style: TextStyle(
                            fontSize: context.getRFontSize(20),
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stock will be added to existing inventory',
                          style: TextStyle(
                            fontSize: context.getRFontSize(13),
                            color: _subtext,
                          ),
                        ),
                        SizedBox(height: context.getRSize(16)),
                        // ── WAREHOUSE SELECTOR ─────────────────────────────
                        if (_warehouses.isEmpty)
                          Text(
                            'No warehouses found. Add a warehouse first.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        else
                          AppDropdown<WarehouseData?>(
                            labelText: 'DESTINATION WAREHOUSE *',
                            value: _selectedWarehouse,
                            items: _warehouses
                                .map(
                                  (w) => DropdownMenuItem(
                                    value: w,
                                    child: Text(w.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedWarehouse = v),
                          ),
                        SizedBox(height: context.getRSize(16)),
                      ],
                    ),
                  ),
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
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
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
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                  ),
                ),
                if (_lines.length > 1)
                  InkWell(
                    onTap: () => _removeLine(index),
                    child: Icon(
                      FontAwesomeIcons.circleMinus,
                      color: Theme.of(context).colorScheme.error,
                      size: context.getRSize(18),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.getRSize(12)),

            _inputField(
              'Product *',
              line.productCtrl,
              'Start typing product name...',
              isAutocomplete: true,
              line: line,
            ),

            const SizedBox(height: 12),

            const SizedBox(height: 0),

            const SizedBox(height: 12),

            AppDropdown<String>(
              labelText: 'Category',
              value: line.selectedCategory,
              items: [
                'Alcoholic',
                'Cans & PET',
                'Kegs',
                'Other',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => line.selectedCategory = v!),
            ),

            if (line.selectedCategory == 'Alcoholic') ...[
              const SizedBox(height: 12),
              AppDropdown<CrateGroupData>(
                labelText: 'Crate Company *',
                value: line.selectedCrateGroup,
                items: _crateGroups.map((cg) {
                  return DropdownMenuItem(
                    value: cg,
                    child: Text('${cg.name} (${cg.size} bottles)'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => line.selectedCrateGroup = v),
              ),
            ],

            const SizedBox(height: 12),

            AppDropdown<Supplier>(
              labelText: 'Supplier *',
              value: line.selectedSupplier,
              items: supplierService.getAll().map((s) {
                return DropdownMenuItem(value: s, child: Text(s.name));
              }).toList(),
              onChanged: (val) => setState(() => line.selectedSupplier = val),
            ),

            const SizedBox(height: 12),

            _inputField(
              'Retail Price',
              line.retailPriceCtrl,
              '0',
              isNumber: true,
            ),

            const SizedBox(height: 12),

            _inputField('Qty *', line.qtyCtrl, '0', isNumber: true),

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

  Widget _buildSummaryBar(
    BuildContext context,
    double grandTotal,
    ScrollController scrollController,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(12),
        context.getRSize(16),
        context.bottomInset + context.getRSize(16),
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
                AppButton(
                  text: 'Add Item',
                  icon: FontAwesomeIcons.plus,
                  variant: AppButtonVariant.ghost,
                  isFullWidth: false,
                  onPressed: () => _addLine(scrollController),
                ),
              ],
            ),
            SizedBox(height: context.getRSize(16)),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Confirm Delivery',
                size: AppButtonSize.large,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

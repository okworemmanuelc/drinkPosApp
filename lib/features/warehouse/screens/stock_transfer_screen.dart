import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/models/inventory_item.dart';
import '../../inventory/data/models/inventory_log.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../warehouse/data/models/warehouse.dart';
import '../../../shared/widgets/fluid_menu.dart';
import '../../../shared/widgets/shared_bottom_nav_bar.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  Warehouse? _sourceWarehouse;
  Warehouse? _destinationWarehouse;
  InventoryItem? _selectedProduct;

  final TextEditingController _productCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();

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
    if (kWarehouses.isNotEmpty) {
      _sourceWarehouse = kWarehouses.first;
      if (kWarehouses.length > 1) {
        _destinationWarehouse = kWarehouses[1];
      }
    }
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;

    if (_sourceWarehouse == null || _destinationWarehouse == null) {
      _showError('Please select both source and destination warehouses.');
      return;
    }

    if (_sourceWarehouse!.id == _destinationWarehouse!.id) {
      _showError('Source and destination warehouses cannot be the same.');
      return;
    }

    if (_selectedProduct == null) {
      _showError('Please select a product.');
      return;
    }

    if (qty <= 0) {
      _showError('Please enter a quantity greater than 0.');
      return;
    }

    final available = _selectedProduct!.getStockForWarehouse(
      _sourceWarehouse!.id,
    );
    if (qty > available) {
      _showError(
        'Insufficient stock in ${_sourceWarehouse!.name}. Available: ${available.toInt()}',
      );
      return;
    }

    // Perform Transfer
    setState(() {
      final newStockMap = Map<String, double>.from(
        _selectedProduct!.warehouseStock,
      );

      // Deduct from source
      newStockMap[_sourceWarehouse!.id] = available - qty;

      // Add to destination
      final destCurrent = _selectedProduct!.getStockForWarehouse(
        _destinationWarehouse!.id,
      );
      newStockMap[_destinationWarehouse!.id] = destCurrent + qty;

      _selectedProduct!.warehouseStock = newStockMap;

      // Log Inventory Movement
      kInventoryLogs.add(
        InventoryLog(
          timestamp: DateTime.now(),
          user: 'System (Transfer)',
          itemId: _selectedProduct!.id,
          itemName: _selectedProduct!.productName,
          action: 'transfer',
          previousValue: available, // Show source stock before
          newValue: available - qty, // Show source stock after
          note:
              'Stock Transfer: ${_sourceWarehouse!.name} -> ${_destinationWarehouse!.name}',
        ),
      );
    });

    // Log Activity (Source)
    await activityLogService.logAction(
      "Stock Transfer (Out)",
      "Transferred ${qty.toInt()} ${_selectedProduct!.productName} OUT to ${_destinationWarehouse!.name}",
      relatedEntityId: _selectedProduct!.id,
      relatedEntityType: "inventory",
      warehouseId: _sourceWarehouse!.id,
    );

    // Log Activity (Destination)
    await activityLogService.logAction(
      "Stock Transfer (In)",
      "Transferred ${qty.toInt()} ${_selectedProduct!.productName} IN from ${_sourceWarehouse!.name}",
      relatedEntityId: _selectedProduct!.id,
      relatedEntityType: "inventory",
      warehouseId: _destinationWarehouse!.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully transferred ${qty.toInt()} items.'),
        backgroundColor: success,
      ),
    );

    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: danger));
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
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const SharedBottomNavBar(),
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: IconThemeData(color: _text),
        title: Text(
          'Stock Transfer',
          style: TextStyle(
            color: _text,
            fontSize: rFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.getRSize(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWarehouseSection(context),
                  SizedBox(height: context.getRSize(24)),
                  _buildProductSection(context),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.getRSize(20),
              0, // Removed extra top spacing
              context.getRSize(20),
              context.getRSize(60),
            ),
            child: Container(
              width: double.infinity,
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
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                icon: Icon(
                  FontAwesomeIcons.rightLeft,
                  size: context.getRSize(16),
                ),
                label: Text(
                  'Confirm Transfer',
                  style: TextStyle(
                    fontSize: context.getRFontSize(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.getRSize(16)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Warehouse Details',
            style: TextStyle(
              color: blueMain,
              fontWeight: FontWeight.bold,
              fontSize: context.getRFontSize(14),
            ),
          ),
          SizedBox(height: context.getRSize(16)),
          FluidMenu<Warehouse>(
            label: 'Source Warehouse',
            value: _sourceWarehouse,
            items: kWarehouses.map((w) {
              return FluidMenuItem(value: w, label: w.name);
            }).toList(),
            onChanged: (val) {
              setState(() {
                _sourceWarehouse = val;
                if (_selectedProduct != null && val != null) {
                  final avail = _selectedProduct!.getStockForWarehouse(val.id);
                  if (avail <= 0) {
                    _selectedProduct = null;
                    _productCtrl.clear();
                    _qtyCtrl.clear();
                  }
                }
              });
            },
          ),
          SizedBox(height: context.getRSize(16)),
          FluidMenu<Warehouse>(
            label: 'Destination Warehouse',
            value: _destinationWarehouse,
            items: kWarehouses.map((w) {
              return FluidMenuItem(value: w, label: w.name);
            }).toList(),
            onChanged: (val) => setState(() => _destinationWarehouse = val),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.getRSize(16)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product & Quantity',
            style: TextStyle(
              color: blueMain,
              fontWeight: FontWeight.bold,
              fontSize: context.getRFontSize(14),
            ),
          ),
          SizedBox(height: context.getRSize(16)),
          _buildFieldLabel('Product'),
          Autocomplete<InventoryItem>(
            displayStringForOption: (item) => item.productName,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<InventoryItem>.empty();
              }
              return kInventoryItems.where((InventoryItem item) {
                // 1. Match search text
                final matchesText = item.productName.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                );
                if (!matchesText) return false;

                // 2. Must have stock in selected source warehouse
                if (_sourceWarehouse == null) return false;
                final stock = item.getStockForWarehouse(_sourceWarehouse!.id);
                return stock > 0;
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(14),
                  color: _surface,
                  child: Container(
                    width:
                        MediaQuery.of(context).size.width -
                        64, // approximate width
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final InventoryItem option = options.elementAt(index);
                        final stock = option.getStockForWarehouse(
                          _sourceWarehouse?.id ?? "",
                        );
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    option.productName,
                                    style: TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: blueMain.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${stock.toInt()} in stock',
                                    style: const TextStyle(
                                      color: blueMain,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (InventoryItem selection) {
              setState(() {
                _selectedProduct = selection;
                _productCtrl.text = selection.productName;
                if (_qtyCtrl.text.isEmpty) _qtyCtrl.text = '1';
                _priceCtrl.text = '0'; // Default price
              });
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
                  if (controller.text.isEmpty && _productCtrl.text.isNotEmpty) {
                    controller.text = _productCtrl.text;
                  }
                  controller.addListener(() {
                    _productCtrl.text = controller.text;
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    style: TextStyle(color: _text, fontWeight: FontWeight.bold),
                    decoration: _inputDeco('Start typing product name...'),
                  );
                },
          ),
          if (_selectedProduct != null) ...[
            SizedBox(height: rSize(context, 8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'Available in source: ${_selectedProduct!.getStockForWarehouse(_sourceWarehouse?.id ?? "").toInt()}',
                style: TextStyle(
                  color: _subtext,
                  fontSize: rFontSize(context, 12),
                ),
              ),
            ),
          ],
          SizedBox(height: rSize(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Unit Price ₦'),
                    TextField(
                      controller: _priceCtrl,
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
                    _buildFieldLabel('Quantity'),
                    TextField(
                      controller: _qtyCtrl,
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
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: _subtext,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


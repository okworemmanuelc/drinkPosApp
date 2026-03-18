import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';

class AddProductSheet extends StatefulWidget {
  final VoidCallback? onProductAdded;
  const AddProductSheet({super.key, this.onProductAdded});

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _nameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _retailPriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _buyingPriceCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController(text: '5');
  final _initialStockCtrl = TextEditingController(text: '0');

  String _unit = 'Bottle';
  String _colorHex = '#3B82F6';
  CrateGroupData? _selectedCrateGroup;
  WarehouseData? _selectedWarehouse;
  List<CrateGroupData> _crateGroups = [];
  List<WarehouseData> _warehouses = [];
  bool _isSaving = false;

  static const _units = ['Bottle', 'Crate', 'Pack', 'Carton', 'Keg', 'Can'];
  static const _colors = [
    '#3B82F6', '#EF4444', '#10B981', '#F59E0B',
    '#8B5CF6', '#EC4899', '#06B6D4', '#F97316',
    '#14B8A6', '#6366F1', '#334155', '#64748B',
  ];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final whs = await database.select(database.warehouses).get();
    final cgs = await database.inventoryDao.getAllCrateGroups();
    if (mounted) {
      setState(() {
        _warehouses = whs;
        _crateGroups = cgs;
        if (whs.isNotEmpty) _selectedWarehouse = whs.first;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _retailPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _buyingPriceCtrl.dispose();
    _lowStockCtrl.dispose();
    _initialStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _retailPriceCtrl.text.trim().isEmpty) return;

    final retailKobo = ((double.tryParse(_retailPriceCtrl.text) ?? 0) * 100).round();
    final sellingKobo = ((double.tryParse(_sellingPriceCtrl.text) ?? 0) * 100).round();
    final buyingKobo = ((double.tryParse(_buyingPriceCtrl.text) ?? 0) * 100).round();
    final lowStock = int.tryParse(_lowStockCtrl.text) ?? 5;
    final initialStock = int.tryParse(_initialStockCtrl.text) ?? 0;

    setState(() => _isSaving = true);
    try {
      final productId = await database.catalogDao.insertProduct(
        ProductsCompanion.insert(
          name: name,
          subtitle: drift.Value(
            _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
          ),
          retailPriceKobo: drift.Value(retailKobo),
          sellingPriceKobo: drift.Value(sellingKobo),
          buyingPriceKobo: drift.Value(buyingKobo),
          unit: drift.Value(_unit),
          colorHex: drift.Value(_colorHex),
          crateGroupId: drift.Value(_selectedCrateGroup?.id),
          lowStockThreshold: drift.Value(lowStock),
        ),
      );

      if (initialStock > 0 && _selectedWarehouse != null) {
        await database.inventoryDao.adjustStock(
          productId,
          _selectedWarehouse!.id,
          initialStock,
          'Initial stock',
          null,
        );
        if (_selectedCrateGroup != null) {
          await database.inventoryDao.addEmptyCrates(
            _selectedCrateGroup!.id,
            initialStock,
          );
        }
      }

      await database.activityLogDao.log(
        action: 'New Product',
        description: 'Product added: $name',
        entityId: productId.toString(),
        entityType: 'Product',
      );

      if (mounted) Navigator.pop(context);
      widget.onProductAdded?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? dSurface : lSurface;
    final card = _isDark ? dCard : lCard;
    final textColor = _isDark ? dText : lText;
    final subtext = _isDark ? dSubtext : lSubtext;
    final border = _isDark ? dBorder : lBorder;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: blueMain.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.boxOpen,
                      color: blueMain,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Product',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Fill in the product details below',
                        style: TextStyle(fontSize: 13, color: subtext),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      'Product Name *',
                      _nameCtrl,
                      'e.g. Heineken 60cl',
                      card, textColor, subtext,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      'Description / Subtitle',
                      _subtitleCtrl,
                      'e.g. Premium Lager',
                      card, textColor, subtext,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Retail Price (₦) *',
                            _retailPriceCtrl,
                            '0.00',
                            card, textColor, subtext,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            'Selling Price (₦)',
                            _sellingPriceCtrl,
                            '0.00',
                            card, textColor, subtext,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Cost Price (₦)',
                            _buyingPriceCtrl,
                            '0.00',
                            card, textColor, subtext,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            'Low Stock Alert',
                            _lowStockCtrl,
                            '5',
                            card, textColor, subtext,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Unit selector
                    Text(
                      'UNIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subtext,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _units.map((u) {
                        final sel = u == _unit;
                        return GestureDetector(
                          onTap: () => setState(() => _unit = u),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? blueMain : card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel ? blueMain : border,
                              ),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : textColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Color selector
                    Text(
                      'COLOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subtext,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colors.map((hex) {
                        final color = Color(
                          int.parse(hex.replaceFirst('#', '0xFF')),
                        );
                        final sel = hex == _colorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _colorHex = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: sel
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: sel
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_crateGroups.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'CRATE GROUP (GLASS PRODUCTS)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtext,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _dropdownWidget<CrateGroupData?>(
                        value: _selectedCrateGroup,
                        items: [
                          DropdownMenuItem<CrateGroupData?>(
                            value: null,
                            child: Text(
                              'None (non-glass product)',
                              style: TextStyle(color: subtext),
                            ),
                          ),
                          ..._crateGroups.map(
                            (cg) => DropdownMenuItem<CrateGroupData?>(
                              value: cg,
                              child: Text(cg.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedCrateGroup = v),
                        card: card,
                        textColor: textColor,
                        border: border,
                      ),
                    ],
                    if (_warehouses.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INITIAL STOCK',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: subtext,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _field(
                                  '',
                                  _initialStockCtrl,
                                  '0',
                                  card, textColor, subtext,
                                  isNumber: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WAREHOUSE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: subtext,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _dropdownWidget<WarehouseData?>(
                                  value: _selectedWarehouse,
                                  items: _warehouses
                                      .map(
                                        (w) => DropdownMenuItem<WarehouseData?>(
                                          value: w,
                                          child: Text(
                                            w.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedWarehouse = v),
                                  card: card,
                                  textColor: textColor,
                                  border: border,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Add Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    Color card,
    Color textColor,
    Color subtext, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subtext,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: ctrl,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: subtext),
            filled: true,
            fillColor: card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: blueMain, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownWidget<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color card,
    required Color textColor,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          dropdownColor: card,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: blueMain,
          ),
        ),
      ),
    );
  }
}

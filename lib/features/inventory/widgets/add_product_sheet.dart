import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/utils/notifications.dart';
import '../../../core/database/app_database.dart';

import '../../../shared/widgets/app_dropdown.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

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
  final _buyingPriceCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController(text: '5');
  final _initialStockCtrl = TextEditingController(text: '0');
  final _supplierCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();

  String _unit = 'Bottle';
  String _colorHex = '#3B82F6';
  String? _crateSize; // null = not a glass product
  WarehouseData? _selectedWarehouse;
  SupplierData? _selectedSupplier;
  CategoryData? _selectedCategory;
  ManufacturerData? _selectedManufacturer;

  List<WarehouseData> _warehouses = [];
  List<SupplierData> _allSuppliers = [];
  List<CategoryData> _allCategories = [];
  List<SupplierData> _supplierSuggestions = [];
  List<ManufacturerData> _allManufacturers = [];
  List<ManufacturerData> _manufacturerSuggestions = [];

  List<ProductData> _allProducts = [];
  List<ProductData> _productSuggestions = [];
  bool _isSaving = false;

  static const _units = ['Bottle', 'Crate', 'Pack', 'Carton', 'Keg', 'Can'];
  static const _colors = [
    '#3B82F6',
    '#EF4444',
    '#10B981',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
    '#06B6D4',
    '#F97316',
    '#14B8A6',
    '#6366F1',
    '#334155',
    '#64748B',
  ];

  bool get _isStockKeeper => authService.currentUser?.role == 'stock_keeper';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final whs = await database.select(database.warehouses).get();
    final suppliers = await database.catalogDao.getAllSuppliers();
    final manufacturers = await database.inventoryDao.getAllManufacturers();
    final cats = await database.select(database.categories).get();
    final productsList = await (database.select(database.products)..where((t) => t.isDeleted.not())).get();

    if (mounted) {
      setState(() {
        _warehouses = whs;
        _allSuppliers = suppliers;
        _allManufacturers = manufacturers;
        _allCategories = cats;
        _allProducts = productsList;
        if (whs.isNotEmpty) _selectedWarehouse = whs.first;
        if (cats.isNotEmpty) _selectedCategory = cats.first;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _retailPriceCtrl.dispose();
    _buyingPriceCtrl.dispose();
    _lowStockCtrl.dispose();
    _initialStockCtrl.dispose();
    _supplierCtrl.dispose();
    _manufacturerCtrl.dispose();
    super.dispose();
  }

  void _onSupplierChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _supplierSuggestions = q.isEmpty
          ? []
          : _allSuppliers
                .where((s) => s.name.toLowerCase().contains(q))
                .take(5)
                .toList();
    });
  }

  void _selectSupplier(SupplierData supplier) {
    _supplierCtrl.text = supplier.name;
    setState(() {
      _selectedSupplier = supplier;
      _supplierSuggestions = [];
    });
  }

  void _clearSupplier() {
    _supplierCtrl.clear();
    setState(() {
      _selectedSupplier = null;
      _supplierSuggestions = [];
    });
  }

  void _onManufacturerChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _manufacturerSuggestions = q.isEmpty
          ? []
          : _allManufacturers
                .where((m) => m.name.toLowerCase().contains(q))
                .take(5)
                .toList();
    });
  }

  void _selectManufacturer(ManufacturerData manufacturer) {
    _manufacturerCtrl.text = manufacturer.name;
    setState(() {
      _selectedManufacturer = manufacturer;
      _manufacturerSuggestions = [];
    });
  }

  void _clearManufacturer() {
    _manufacturerCtrl.clear();
    setState(() {
      _selectedManufacturer = null;
      _manufacturerSuggestions = [];
    });
  }

  void _onNameChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _productSuggestions = q.isEmpty
          ? []
          : _allProducts
                .where((p) => p.name.toLowerCase().contains(q))
                .take(5)
                .toList();
    });
  }

  void _selectProduct(ProductData product) {
    _nameCtrl.text = product.name;
    _subtitleCtrl.text = product.subtitle ?? '';
    _retailPriceCtrl.text = (product.retailPriceKobo / 100).toStringAsFixed(2);
    _buyingPriceCtrl.text = (product.buyingPriceKobo / 100).toStringAsFixed(2);
    _lowStockCtrl.text = product.lowStockThreshold.toString();
    
    setState(() {
      _unit = product.unit;
      _colorHex = product.colorHex ?? '#3B82F6';
      _crateSize = product.crateSize;
      _selectedCategory = _allCategories.cast<CategoryData?>().firstWhere(
        (c) => c?.id == product.categoryId,
        orElse: () => _selectedCategory,
      );
      _selectedManufacturer = _allManufacturers.cast<ManufacturerData?>().firstWhere(
        (m) => m?.id == product.manufacturerId,
        orElse: () => null,
      );
      if (_selectedManufacturer != null) {
        _manufacturerCtrl.text = _selectedManufacturer!.name;
      }
      _selectedSupplier = _allSuppliers.cast<SupplierData?>().firstWhere(
        (s) => s?.id == product.supplierId,
        orElse: () => null,
      );
      if (_selectedSupplier != null) {
        _supplierCtrl.text = _selectedSupplier!.name;
      }
      _productSuggestions = [];
    });
  }

  Future<void> _createNewManufacturer(String name) async {
    final id = await database.inventoryDao.insertManufacturer(
      ManufacturersCompanion.insert(name: name),
    );
    final manufacturers = await database.inventoryDao.getAllManufacturers();
    final newM = manufacturers.firstWhere((m) => m.id == id);
    setState(() {
      _allManufacturers = manufacturers;
      _selectManufacturer(newM);
    });
  }

  Future<void> _createNewSupplier(String name) async {
    final id = await database.catalogDao.insertSupplier(
      SuppliersCompanion.insert(name: name),
    );
    final suppliers = await database.catalogDao.getAllSuppliers();
    final newS = suppliers.firstWhere((s) => s.id == id);
    setState(() {
      _allSuppliers = suppliers;
      _selectSupplier(newS);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    String? missingField;
    if (name.isEmpty) {
      missingField = 'Product Name';
    } else if (_subtitleCtrl.text.trim().isEmpty) {
      missingField = 'Description / Subtitle';
    } else if (_selectedCategory == null) {
      missingField = 'Category';
    } else if (_retailPriceCtrl.text.trim().isEmpty) {
      missingField = 'Retail Price';
    } else if (!_isStockKeeper && _buyingPriceCtrl.text.trim().isEmpty) {
      missingField = 'Buying Price';
    } else if (_lowStockCtrl.text.trim().isEmpty) {
      missingField = 'Low Stock Alert';
    } else if (_selectedWarehouse == null) {
      missingField = 'Warehouse';
    } else if (_selectedManufacturer == null) {
      missingField = 'Manufacturer';
    } else if (_selectedSupplier == null) {
      missingField = 'Supplier';
    } else if (_initialStockCtrl.text.trim().isEmpty) {
      missingField = 'Initial Quantity';
    }

    if (missingField != null) {
      if (mounted) {
        AppNotification.showError(context, '$missingField is required.');
      }
      return;
    }

    final retailPrice = double.tryParse(_retailPriceCtrl.text) ?? 0;
    final buyingPrice = double.tryParse(_buyingPriceCtrl.text) ?? 0;

    if (buyingPrice > retailPrice) {
      if (mounted) {
        AppNotification.showError(
          context,
          'Buying price (₦$buyingPrice) cannot be higher than retail price (₦$retailPrice).',
        );
      }
      return;
    }

    // Check for duplicate product name
    final existing = await database.catalogDao.findByName(name);
    if (existing != null) {
      if (mounted) {
        AppNotification.showError(context, 'A product named "$name" already exists.');
      }
      return;
    }

    final retailKobo = (retailPrice * 100).round();
    final buyingKobo = (buyingPrice * 100).round();
    final lowStock = int.tryParse(_lowStockCtrl.text) ?? 5;
    final initialStock = int.tryParse(_initialStockCtrl.text) ?? 0;

    setState(() => _isSaving = true);
    try {
      final productId = await database.catalogDao.insertProduct(
        ProductsCompanion.insert(
          name: name,
          subtitle: drift.Value(
            _subtitleCtrl.text.trim().isEmpty
                ? null
                : _subtitleCtrl.text.trim(),
          ),
          retailPriceKobo: drift.Value(retailKobo),
          sellingPriceKobo: drift.Value(retailKobo),
          buyingPriceKobo: drift.Value(buyingKobo),
          unit: drift.Value(_unit),
          colorHex: drift.Value(_colorHex),
          crateSize: drift.Value(_crateSize),
          lowStockThreshold: drift.Value(lowStock),
          // Store both the FK id and the display name so existing text queries work
          manufacturerId: drift.Value(_selectedManufacturer?.id),
          manufacturer: drift.Value(_selectedManufacturer?.name),
          supplierId: drift.Value(_selectedSupplier?.id),
          categoryId: drift.Value(_selectedCategory?.id),
        ),
      );

      if (initialStock > 0 && _selectedWarehouse != null) {
        await database.inventoryDao.adjustStock(
          productId,
          _selectedWarehouse!.id,
          initialStock,
          'Initial stock by ${authService.currentUser?.name ?? 'Unknown'}',
          authService.currentUser?.id,
        );
      }

      await activityLogService.logAction(
        'new_product',
        '${authService.currentUser?.name ?? 'Unknown'} added product: $name'
            '${initialStock > 0 ? ' with initial stock $initialStock' : ''}',
        relatedEntityId: productId.toString(),
        relatedEntityType: 'product',
      );

      if (mounted) Navigator.pop(context);
      widget.onProductAdded?.call();
    } catch (e) {
      debugPrint('AddProductSheet._save error: $e');
      if (mounted) {
        AppNotification.showError(context, 'Could not save product: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final card = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtext = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
    final border = Theme.of(context).dividerColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: context.bottomInset,
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FontAwesomeIcons.boxOpen,
                      color: Theme.of(context).colorScheme.primary,
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
            // Scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInput(
                      controller: _nameCtrl,
                      labelText: 'Product Name *',
                      hintText: 'e.g. Heineken 60cl',
                      prefixIcon: Icon(Icons.search, size: 18, color: subtext),
                      onChanged: _onNameChanged,
                    ),
                    if (_productSuggestions.isNotEmpty)
                      _suggestionList(
                        children: _productSuggestions.map(
                          (p) => _suggestionTile(
                            label: p.name,
                            textColor: textColor,
                            card: card,
                            border: border,
                            onTap: () => _selectProduct(p),
                          ),
                        ).toList(),
                        card: card,
                        border: border,
                      ),
                    const SizedBox(height: 14),
                    _sectionLabel('CATEGORY *', subtext),
                    const SizedBox(height: 8),
                    if (_allCategories.isEmpty)
                      Text(
                        'No categories found',
                        style: TextStyle(color: subtext, fontSize: 13),
                      )
                    else
                      AppDropdown<CategoryData?>(
                        value: _selectedCategory,
                        items: _allCategories
                            .map(
                              (c) => DropdownMenuItem<CategoryData?>(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _subtitleCtrl,
                      labelText: 'Description / Subtitle *',
                      hintText: 'e.g. Premium Lager',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            controller: _retailPriceCtrl,
                            labelText: 'Retail Price (₦) *',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!_isStockKeeper)
                          Expanded(
                            child: AppInput(
                              controller: _buyingPriceCtrl,
                              labelText: 'Buying Price (₦) *',
                              hintText: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppInput(
                      controller: _lowStockCtrl,
                      labelText: 'Low Stock Alert *',
                      hintText: '5',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // ── UNIT SELECTOR ──────────────────────────────────────
                    _sectionLabel('UNIT *', subtext),
                    const SizedBox(height: 8),
                    AppDropdown<String>(
                      value: _unit,
                      items: _units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _unit = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── COLOR SELECTOR ─────────────────────────────────────
                    _sectionLabel('COLOR', subtext),
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
                    const SizedBox(height: 16),

                    // ── CRATE SIZE ─────────────────────────────────────────
                    _sectionLabel('CRATE SIZE', subtext),
                    const SizedBox(height: 4),
                    Text(
                      'Only select for glass / bottle products',
                      style: TextStyle(fontSize: 11, color: subtext),
                    ),
                    const SizedBox(height: 8),
                    AppDropdown<String?>(
                      value: _crateSize,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('None')),
                        DropdownMenuItem(value: 'big', child: Text('Big')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'small', child: Text('Small')),
                      ],
                      onChanged: (v) => setState(() => _crateSize = v),
                    ),
                    const SizedBox(height: 16),

                    // ── MANUFACTURER ───────────────────────────────────────
                    AppInput(
                      controller: _manufacturerCtrl,
                      labelText: 'MANUFACTURER *',
                      hintText: 'Search or type manufacturer name…',
                      prefixIcon: Icon(Icons.search, size: 18, color: subtext),
                      onChanged: _onManufacturerChanged,
                      suffixIcon: _selectedManufacturer != null
                          ? GestureDetector(
                              onTap: _clearManufacturer,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: subtext,
                              ),
                            )
                          : null,
                    ),
                    if (_manufacturerSuggestions.isNotEmpty ||
                        (_manufacturerCtrl.text.trim().isNotEmpty &&
                            _selectedManufacturer == null))
                      _suggestionList(
                        children: [
                          ..._manufacturerSuggestions.map(
                            (m) => _suggestionTile(
                              label: m.name,
                              textColor: textColor,
                              card: card,
                              border: border,
                              onTap: () => _selectManufacturer(m),
                            ),
                          ),
                          if (_manufacturerCtrl.text.trim().isNotEmpty &&
                              !_manufacturerSuggestions.any((m) =>
                                  m.name.toLowerCase() ==
                                  _manufacturerCtrl.text.trim().toLowerCase()))
                            _suggestionTile(
                              label: 'Create "${_manufacturerCtrl.text.trim()}"',
                              icon: Icons.add_circle_outline,
                              textColor: Theme.of(context).colorScheme.primary,
                              card: card,
                              border: border,
                              onTap: () => _createNewManufacturer(
                                  _manufacturerCtrl.text.trim()),
                            ),
                        ],
                        card: card,
                        border: border,
                      ),
                    const SizedBox(height: 16),

                    // ── SUPPLIER ───────────────────────────────────────────
                    AppInput(
                      controller: _supplierCtrl,
                      labelText: 'SUPPLIER *',
                      hintText: 'Search supplier name…',
                      prefixIcon: Icon(Icons.search, size: 18, color: subtext),
                      onChanged: _onSupplierChanged,
                      suffixIcon: _selectedSupplier != null
                          ? GestureDetector(
                              onTap: _clearSupplier,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: subtext,
                              ),
                            )
                          : null,
                    ),
                    if (_supplierSuggestions.isNotEmpty ||
                        (_supplierCtrl.text.trim().isNotEmpty &&
                            _selectedSupplier == null))
                      _suggestionList(
                        children: [
                          ..._supplierSuggestions.map(
                            (s) => _suggestionTile(
                              label: s.name,
                              textColor: textColor,
                              card: card,
                              border: border,
                              onTap: () => _selectSupplier(s),
                            ),
                          ),
                          if (_supplierCtrl.text.trim().isNotEmpty &&
                              !_supplierSuggestions.any((s) =>
                                  s.name.toLowerCase() ==
                                  _supplierCtrl.text.trim().toLowerCase()))
                            _suggestionTile(
                              label: 'Create "${_supplierCtrl.text.trim()}"',
                              icon: Icons.add_circle_outline,
                              textColor: Theme.of(context).colorScheme.primary,
                              card: card,
                              border: border,
                              onTap: () => _createNewSupplier(
                                  _supplierCtrl.text.trim()),
                            ),
                        ],
                        card: card,
                        border: border,
                      ),
                    const SizedBox(height: 16),

                    // ── QUANTITY ────────────────────────────────────────────
                    AppInput(
                      controller: _initialStockCtrl,
                      labelText: 'INITIAL QUANTITY *',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('WAREHOUSE *', subtext),
                        const SizedBox(height: 8),
                        if (_warehouses.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              'No warehouses',
                              style: TextStyle(
                                fontSize: 14,
                                color: subtext,
                              ),
                            ),
                          )
                        else
                          AppDropdown<WarehouseData?>(
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
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: AppButton(
                text: 'Add Product',
                variant: AppButtonVariant.primary,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, Color subtext) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: subtext,
      letterSpacing: 0.8,
    ),
  );



  Widget _suggestionList({
    required List<Widget> children,
    required Color card,
    required Color border,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _suggestionTile({
    required String label,
    required Color textColor,
    required Color card,
    required Color border,
    required VoidCallback onTap,
    IconData icon = Icons.person_outline,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


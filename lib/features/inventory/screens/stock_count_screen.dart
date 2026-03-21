import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/widgets/shared_bottom_nav_bar.dart';

class StockCountScreen extends StatefulWidget {
  /// If provided, only products in this warehouse are loaded and adjustments
  /// are written to this warehouse. Null means all warehouses (totals).
  final int? warehouseId;

  const StockCountScreen({super.key, this.warehouseId});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  List<ProductDataWithStock> _products = [];
  final List<TextEditingController> _controllers = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _card => _isDark ? dCard : lCard;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await database.inventoryDao
        .getProductsWithStock(warehouseId: widget.warehouseId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _controllers.clear();
      for (final p in products) {
        _controllers.add(
          TextEditingController(text: p.totalStock.toString()),
        );
      }
      _loading = false;
    });
  }

  int _diff(int index) {
    final actual = int.tryParse(_controllers[index].text) ?? 0;
    return actual - _products[index].totalStock;
  }

  Future<void> _saveCount() async {
    setState(() => _saving = true);

    // Decide which warehouse to write adjustments to.
    // Use the screen's warehouseId, or fall back to the first warehouse in DB.
    int? targetWarehouseId = widget.warehouseId;
    if (targetWarehouseId == null) {
      final warehouses = await database.select(database.warehouses).get();
      if (warehouses.isNotEmpty) targetWarehouseId = warehouses.first.id;
    }

    if (targetWarehouseId == null) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No warehouse found. Cannot save.')),
        );
      }
      return;
    }

    int adjustedCount = 0;
    for (int i = 0; i < _products.length; i++) {
      final diff = _diff(i);
      if (diff == 0) continue;

      final product = _products[i].product;
      await database.inventoryDao.adjustStock(
        product.id,
        targetWarehouseId,
        diff,
        'Daily stock count adjustment',
        null,
      );

      final sign = diff > 0 ? '+' : '';
      await activityLogService.logAction(
        'stock_count',
        'Stock count: ${product.name} adjusted by $sign$diff '
            '(system: ${_products[i].totalStock}, '
            'actual: ${_products[i].totalStock + diff})',
        relatedEntityId: product.id.toString(),
        relatedEntityType: 'product',
      );

      adjustedCount++;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          adjustedCount == 0
              ? 'No changes — all counts matched.'
              : '$adjustedCount product${adjustedCount == 1 ? '' : 's'} adjusted.',
        ),
        backgroundColor: adjustedCount == 0 ? null : success,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        bottomNavigationBar: const SharedBottomNavBar(),
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Stock Count',
                style: TextStyle(
                  color: _text,
                  fontSize: context.getRFontSize(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.warehouseId != null)
                Text(
                  'Warehouse #${widget.warehouseId}',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(11),
                  ),
                ),
            ],
          ),
          actions: [
            if (!_loading)
              _saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: blueMain,
                          ),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _saveCount,
                      child: Text(
                        'Save Count',
                        style: TextStyle(
                          color: blueMain,
                          fontWeight: FontWeight.w700,
                          fontSize: context.getRFontSize(14),
                        ),
                      ),
                    ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: blueMain,
                  strokeWidth: 2,
                ),
              )
            : _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.boxOpen,
                          size: context.getRSize(48),
                          color: _subtext.withValues(alpha: 0.4),
                        ),
                        SizedBox(height: context.getRSize(16)),
                        Text(
                          'No products found',
                          style: TextStyle(
                            color: _subtext,
                            fontSize: context.getRFontSize(16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildTable(context),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Column(
      children: [
        _buildTableHeader(context),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: context.getRSize(24) + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _products.length,
            itemBuilder: (_, i) => _buildRow(context, i),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final style = TextStyle(
      color: _subtext,
      fontSize: context.getRFontSize(11),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(10),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('PRODUCT', style: style)),
          SizedBox(
            width: context.getRSize(56),
            child: Text('SYSTEM', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: context.getRSize(72),
            child: Text('ACTUAL', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: context.getRSize(56),
            child: Text('DIFF', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final product = _products[i].product;
    final systemStock = _products[i].totalStock;

    return StatefulBuilder(
      builder: (context, setRowState) {
        final diff = _diff(i);
        final diffColor = diff > 0
            ? success
            : diff < 0
                ? danger
                : _subtext;
        final diffLabel = diff == 0 ? '—' : (diff > 0 ? '+$diff' : '$diff');

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(4),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(12),
            vertical: context.getRSize(10),
          ),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: diff != 0 ? diffColor.withValues(alpha: 0.4) : _border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  product.name,
                  style: TextStyle(
                    color: _text,
                    fontSize: context.getRFontSize(13),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: context.getRSize(56),
                child: Text(
                  '$systemStock',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                ),
              ),
              SizedBox(
                width: context.getRSize(72),
                child: TextField(
                  controller: _controllers[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _text,
                    fontSize: context.getRFontSize(13),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(6),
                      vertical: context.getRSize(8),
                    ),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: blueMain, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setRowState(() {}),
                ),
              ),
              SizedBox(
                width: context.getRSize(56),
                child: Text(
                  diffLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: diffColor,
                    fontSize: context.getRFontSize(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

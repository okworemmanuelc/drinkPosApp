import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/stock_calculator.dart';
import '../data/models/inventory_item.dart';
import '../data/models/supplier.dart';
import '../data/services/supplier_service.dart';
import '../data/models/crate_group.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/services/cart_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProductDetailScreen — full-screen product information view
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onUpdateStock;

  const ProductDetailScreen({
    super.key,
    required this.item,
    required this.onUpdateStock,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _subtitleController;
  late TextEditingController _quantityController;
  late TextEditingController _manufacturerController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _retailPriceController;
  late TextEditingController _bulkBreakerPriceController;
  late TextEditingController _distributorPriceController;
  late TextEditingController _monthlyTargetController;
  int _monthlyTarget = 200;

  int? _emptyCrateStock;
  late Future<List<ActivityLogData>> _deliveryLogsFuture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.productName);
    _subtitleController = TextEditingController(text: widget.item.subtitle);
    _quantityController = TextEditingController(
      text: widget.item.totalStock.toStringAsFixed(
        widget.item.totalStock % 1 == 0 ? 0 : 1,
      ),
    );
    _manufacturerController = TextEditingController(text: widget.item.manufacturer ?? '');
    _sellingPriceController = TextEditingController(text: (widget.item.sellingPrice ?? 0).toString());
    _buyingPriceController = TextEditingController(text: (widget.item.buyingPrice ?? 0).toString());
    _retailPriceController = TextEditingController(text: (widget.item.retailPrice ?? 0).toString());
    _bulkBreakerPriceController = TextEditingController(text: (widget.item.bulkBreakerPrice ?? 0).toString());
    _distributorPriceController = TextEditingController(text: (widget.item.distributorPrice ?? 0).toString());
    _monthlyTargetController = TextEditingController(
      text: _monthlyTarget.toString(),
    );
    _deliveryLogsFuture =
        database.activityLogDao.getForEntity(widget.item.id);
    if (widget.item.crateGroupName != null) {
      _loadEmptyCrateStock();
    }
  }

  Future<void> _loadEmptyCrateStock() async {
    final groups = await database.inventoryDao.getAllCrateGroups();
    final match = groups.where((g) => g.name == widget.item.crateGroupName);
    if (match.isNotEmpty && mounted) {
      setState(() => _emptyCrateStock = match.first.emptyCrateStock);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _quantityController.dispose();
    _manufacturerController.dispose();
    _sellingPriceController.dispose();
    _buyingPriceController.dispose();
    _retailPriceController.dispose();
    _bulkBreakerPriceController.dispose();
    _distributorPriceController.dispose();
    _monthlyTargetController.dispose();
    super.dispose();
  }

  // ── Theme helpers ─────────────────────────────────────────────────────────
  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lCard;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildBody(context)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLIVER APP BAR — hero header with product icon and gradient
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSliverAppBar(BuildContext context) {
    final isLow =
        widget.item.totalStock > 0 &&
        widget.item.totalStock <= widget.item.lowStockThreshold;
    final isOut = widget.item.totalStock == 0;
    Color statusColor = success;
    String statusLabel = 'In Stock';
    if (isOut) {
      statusColor = danger;
      statusLabel = 'Out of Stock';
    } else if (isLow) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Low Stock';
    }

    return SliverAppBar(
      expandedHeight: context.getRSize(220),
      pinned: true,
      backgroundColor: _surface,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(context.getRSize(8)),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: context.getRSize(18),
            color: Colors.white,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          onPressed: () => _confirmDelete(context),
          icon: Container(
            padding: EdgeInsets.all(context.getRSize(8)),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              FontAwesomeIcons.trashCan,
              size: context.getRSize(18),
              color: danger,
            ),
          ),
        ),
        SizedBox(width: context.getRSize(8)),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.item.color.withValues(alpha: 0.8),
                widget.item.color.withValues(alpha: 0.4),
                _bg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: context.getRSize(24)), // offset for app bar
                // Product icon
                Container(
                  width: context.getRSize(80),
                  height: context.getRSize(80),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          widget.item.icon,
                          color: Colors.white,
                          size: context.getRSize(36),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: EdgeInsets.all(context.getRSize(4)),
                            decoration: BoxDecoration(
                              color: blueMain,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: context.getRSize(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.getRSize(14)),
                // Product name
                _nameController.text.isEmpty
                    ? Text(
                        widget.item.productName,
                        style: TextStyle(
                          fontSize: context.getRFontSize(24),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.8),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: context.getRFontSize(24),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Product Name',
                            hintStyle: TextStyle(color: Colors.white60),
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                SizedBox(height: context.getRSize(6)),
                // Status badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: context.getRSize(12)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(10),
                        vertical: context.getRSize(4),
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: context.getRFontSize(11),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY — all detail sections
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBody(BuildContext context) {
    // Look up related data
    final allSuppliers = supplierService.getAll();
    Supplier? supplier;
    if (widget.item.supplierId != null) {
      for (final s in allSuppliers) {
        if (s.id == widget.item.supplierId) {
          supplier = s;
          break;
        }
      }
    }

    // Crate stock and delivery logs will be handled via FutureBuilder/StreamBuilder below
    final double totalStockValue = stockValue(
      (widget.item.sellingPrice ?? 0).toDouble(),
      widget.item.totalStock,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(20),
        vertical: context.getRSize(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stock & Supplier ─────────────────────────────────────────
          _sectionTitle(context, 'Stock & Supplier'),
          SizedBox(height: context.getRSize(12)),
          _infoCard(context, [
            _infoRow(
              context,
              FontAwesomeIcons.cubesStacked,
              'Total Quantity',
              '',
              blueMain,
              trailing: Container(
                width: context.getRSize(100),
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(8),
                  vertical: context.getRSize(4),
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.getRFontSize(14),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.industry,
              'Manufacturer',
              '',
              const Color(0xFF6366F1),
              trailing: Container(
                width: context.getRSize(120),
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(8),
                  vertical: context.getRSize(4),
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _manufacturerController,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: context.getRFontSize(13),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'Crate Company',
                    hintStyle: TextStyle(fontSize: 10),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.beerMugEmpty,
              'Empty Crates ${supplier != null ? "(${supplier.crateGroup.label})" : ""}',
              _emptyCrateStock != null ? '$_emptyCrateStock crates' : 'N/A',
              supplier?.crateGroup.color ?? _subtext,
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.layerGroup,
              'Crate Company',
              widget.item.crateGroupName ?? 'Not Assigned',
              const Color(0xFF8B5CF6),
              onTap: () => _showCrateGroupSelectionSheet(context),
              trailing: Icon(
                FontAwesomeIcons.chevronRight,
                size: context.getRSize(12),
                color: _subtext,
              ),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.buildingColumns,
              'Supplier',
              supplier?.name ?? 'Not Assigned',
              const Color(0xFF6366F1),
              onTap: () => _showSupplierSelectionSheet(context),
              trailing: Icon(
                FontAwesomeIcons.chevronRight,
                size: context.getRSize(12),
                color: _subtext,
              ),
            ),
          ]),

          SizedBox(height: context.getRSize(24)),

          // ── Pricing ─────────────────────────────────────────────────
          _sectionTitle(context, 'Pricing'),
          SizedBox(height: context.getRSize(12)),
          _infoCard(context, [
            _infoRow(
              context,
              FontAwesomeIcons.tags,
              'Selling Price',
              '',
              success,
              trailing: _inlinePriceInput(_sellingPriceController),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.dollarSign,
              'Buying Price',
              '',
              const Color(0xFFF59E0B),
              trailing: _inlinePriceInput(_buyingPriceController),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.tag,
              'Retail Price',
              '',
              blueMain,
              trailing: _inlinePriceInput(_retailPriceController),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.users,
              'Bulk Breaker Price',
              '',
              const Color(0xFF8B5CF6),
              trailing: _inlinePriceInput(_bulkBreakerPriceController),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.truck,
              'Distributor Price',
              '',
              const Color(0xFFEC4899),
              trailing: _inlinePriceInput(_distributorPriceController),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.chartLine,
              'Total Stock Value',
              formatCurrency(totalStockValue),
              blueMain,
            ),
          ]),

          SizedBox(height: context.getRSize(24)),

          // ── Sales Summary ───────────────────────────────────────────
          _sectionTitle(context, 'Sales Summary'),
          SizedBox(height: context.getRSize(12)),
          _buildSalesGrid(context),

          SizedBox(height: context.getRSize(24)),

          // ── Sales Target ────────────────────────────────────────────
          _sectionTitle(context, 'Sales Target'),
          SizedBox(height: context.getRSize(12)),
          _buildTargetGrid(context),

          SizedBox(height: context.getRSize(24)),

          // ── Last Delivery ───────────────────────────────────────────
          _sectionTitle(context, 'Last Delivery'),
          SizedBox(height: context.getRSize(12)),
          FutureBuilder<List<ActivityLogData>>(
            future: _deliveryLogsFuture,
            builder: (ctx, snap) => _buildDeliveryCard(
              ctx,
              snap.data ?? [],
              (widget.item.buyingPrice ?? 0).toInt(),
            ),
          ),

          SizedBox(height: context.getRSize(40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM BAR — Update Stock button
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.getRSize(20),
          context.getRSize(12),
          context.getRSize(20),
          context.getRSize(12),
        ),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: blueMain,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: Icon(FontAwesomeIcons.check, size: context.getRSize(16)),
            label: Text(
              'Update Product',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(16),
              ),
            ),
            onPressed: _updateProduct,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: context.getRFontSize(16),
        fontWeight: FontWeight.w800,
        color: _text,
      ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.getRSize(16),
          vertical: context.getRSize(14),
        ),
        child: Row(
          children: [
            Container(
              width: context.getRSize(38),
              height: context.getRSize(38),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: context.getRSize(16), color: iconColor),
            ),
            SizedBox(width: context.getRSize(14)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: _subtext,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: context.getRSize(8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: context.getRFontSize(14),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (trailing != null) ...[
              SizedBox(width: context.getRSize(8)),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      color: _border,
      indent: context.getRSize(16),
      endIndent: context.getRSize(16),
    );
  }

  // ── Sales Summary Grid ────────────────────────────────────────────────────
  Widget _buildSalesGrid(BuildContext context) {
    // Mock data — replace with real sales tracking later
    return _infoCard(context, [
      _statRow(context, 'Today', '4 units', formatCurrency(20000)),
      _divider(context),
      _statRow(context, 'This Week', '18 units', formatCurrency(90000)),
      _divider(context),
      _statRow(context, 'This Month', '62 units', formatCurrency(310000)),
    ]);
  }

  // ── Sales Target Grid ─────────────────────────────────────────────────────
  Widget _buildTargetGrid(BuildContext context) {
    // Mock current sales (Quantity Sold)
    const int currentMonthly = 62;
    const int currentWeekly = 18;
    const int currentDaily = 4;

    return _infoCard(context, [
      _targetRow(context, 'Daily', currentDaily, _monthlyTarget ~/ 30),
      _divider(context),
      _targetRow(context, 'Weekly', currentWeekly, _monthlyTarget ~/ 4),
      _divider(context),
      _targetRow(
        context,
        'Monthly',
        currentMonthly,
        _monthlyTarget,
        isEditable: true,
      ),
    ]);
  }

  Widget _statRow(
    BuildContext context,
    String period,
    String qty,
    String revenue,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(14),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              period,
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.w600,
                color: _subtext,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              qty, // Quantity Sold (Read-Only)
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.bold,
                color: _text,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              revenue,
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.bold,
                color: success,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetRow(
    BuildContext context,
    String period,
    int current,
    int target, {
    bool isEditable = false,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                period,
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: _subtext,
                ),
              ),
              if (isEditable)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$current / ',
                      style: TextStyle(
                        fontSize: context.getRFontSize(12),
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    SizedBox(
                      width: context.getRSize(40),
                      child: TextField(
                        controller: _monthlyTargetController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: context.getRFontSize(12),
                          fontWeight: FontWeight.bold,
                          color: blueMain,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _monthlyTarget = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                    Text(
                      ' units ($pct%)',
                      style: TextStyle(
                        fontSize: context.getRFontSize(12),
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '$current / $target units  ($pct%)',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.getRSize(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: context.getRSize(6),
              backgroundColor: _border,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? success : blueMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Last Delivery Card ────────────────────────────────────────────────────
  Widget _buildDeliveryCard(
    BuildContext context,
    List<ActivityLogData> deliveryLogs,
    int buyingPrice,
  ) {
    if (deliveryLogs.isEmpty) {
      // Mock delivery data when no logs exist
      final mockDate = DateTime.now().subtract(const Duration(days: 3));
      const mockQty = 10;
      return _infoCard(context, [
        _infoRow(
          context,
          FontAwesomeIcons.calendarDay,
          'Date',
          _fmtDate(mockDate),
          blueMain,
        ),
        _divider(context),
        _infoRow(
          context,
          FontAwesomeIcons.truckFast,
          'Quantity Received',
          '$mockQty units',
          const Color(0xFF6366F1),
        ),
        _divider(context),
        _infoRow(
          context,
          FontAwesomeIcons.dollarSign,
          'Price Per Unit',
          formatCurrency(buyingPrice),
          const Color(0xFFF59E0B),
        ),
        _divider(context),
        _infoRow(
          context,
          FontAwesomeIcons.receipt,
          'Total Delivery Cost',
          formatCurrency(buyingPrice * mockQty),
          success,
        ),
      ]);
    }

    final last = deliveryLogs.first;
    // ActivityLogData doesn't have newValue/previousValue. Fallback to 0 or parse description.
    const qty = 0; 
    return _infoCard(context, [
      _infoRow(
        context,
        FontAwesomeIcons.calendarDay,
        'Date',
        _fmtDate(last.timestamp),
        blueMain,
      ),
      _divider(context),
      _infoRow(
        context,
        FontAwesomeIcons.truckFast,
        'Quantity Received',
        '$qty units',
        const Color(0xFF6366F1),
      ),
      _divider(context),
      _infoRow(
        context,
        FontAwesomeIcons.dollarSign,
        'Price Per Unit',
        formatCurrency(widget.item.buyingPrice ?? 0),
        const Color(0xFFF59E0B),
      ),
      _divider(context),
      _infoRow(
        context,
        FontAwesomeIcons.receipt,
        'Total Delivery Cost',
        formatCurrency((widget.item.buyingPrice ?? 0) * qty),
        success,
      ),
    ]);
  }

  String _fmtDate(DateTime dt) {
    const months = [
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _showCrateGroupSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _isDark ? dSurface : lSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Assign Crate Company',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<List<CrateGroupData>>(
              future: database.inventoryDao.getAllCrateGroups(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  );
                }
                final groups = snap.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.close, color: Colors.grey),
                      title: Text(
                        'Remove Crate Company',
                        style: TextStyle(color: _subtext),
                      ),
                      onTap: () {
                        setState(() => widget.item.crateGroupName = null);
                        Navigator.pop(ctx);
                        _updateDbCrateGroup(null, null);
                      },
                    ),
                    const Divider(height: 1),
                    ...groups.map(
                      (cg) => ListTile(
                        leading: const Icon(
                          Icons.layers,
                          color: Color(0xFF8B5CF6),
                        ),
                        title: Text(
                          cg.name,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${cg.size} bottles · ${cg.emptyCrateStock} empty crates available',
                          style: TextStyle(color: _subtext, fontSize: 12),
                        ),
                        trailing: widget.item.crateGroupName == cg.name
                            ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
                            : null,
                        onTap: () {
                          setState(() => widget.item.crateGroupName = cg.name);
                          Navigator.pop(ctx);
                          _updateDbCrateGroup(cg.id, _crateSizeLabel(cg.size));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _crateSizeLabel(int size) {
    if (size == 12) return 'big';
    if (size == 20) return 'medium';
    return 'small';
  }

  /// Finds the DB product by name and updates crateGroupId + crateSize.
  Future<void> _updateDbCrateGroup(int? crateGroupId, String? crateSize) async {
    final dbProducts = await database.select(database.products).get();
    final match = dbProducts
        .where((p) => p.name == widget.item.productName)
        .firstOrNull;
    if (match != null) {
      await database.inventoryDao.assignCrateGroup(
        match.id,
        crateGroupId,
        crateSize,
      );
    }
  }

  void _showSupplierSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) => GestureDetector(
            onTap: () {}, // absorb taps inside
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Assign Supplier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: supplierService.getAll().length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.close,
                                color: _subtext,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              'No Supplier',
                              style: TextStyle(color: _text),
                            ),
                            onTap: () {
                              setState(() {
                                widget.item.supplierId = null;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        }
                        final s = supplierService.getAll()[index - 1];
                        final isSelected = widget.item.supplierId == s.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: s.crateGroup.color.withValues(alpha: 0.1),
                            child: Icon(
                              FontAwesomeIcons.building,
                              color: s.crateGroup.color,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: TextStyle(
                              color: _text,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: success)
                              : null,
                          onTap: () {
                            setState(() {
                              widget.item.supplierId = s.id;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pickImage() {
    // In a real app, this would use image_picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picking not implemented (Mock)')),
    );
  }



  Widget _inlinePriceInput(TextEditingController controller) {
    return Container(
      width: context.getRSize(100),
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(8),
        vertical: context.getRSize(4),
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: context.getRFontSize(14),
          fontWeight: FontWeight.bold,
          color: _text,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          prefixText: '₦',
          prefixStyle: TextStyle(fontSize: 12),
        ),
        onChanged: (v) => setState(() {}),
      ),
    );
  }

  Future<void> _updateProduct() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name cannot be empty')),
      );
      return;
    }

    final newQty = double.tryParse(_quantityController.text) ?? widget.item.totalStock;
    final manufacturer = _manufacturerController.text.trim();
    final selling = double.tryParse(_sellingPriceController.text) ?? 0;
    final buying = double.tryParse(_buyingPriceController.text) ?? 0;
    final retail = double.tryParse(_retailPriceController.text) ?? 0;
    final bulk = double.tryParse(_bulkBreakerPriceController.text) ?? 0;
    final distributor = double.tryParse(_distributorPriceController.text) ?? 0;

    final productId = int.parse(widget.item.id);

    try {
      // 1. Update Products table — stub, no DB write in this version

      // 2. Update Inventory (adjusting qty)
      final warehouseId = widget.item.warehouseStock.keys.isNotEmpty
          ? int.tryParse(widget.item.warehouseStock.keys.first.replaceAll('w', '')) ?? 1
          : 1;

      final diff = (newQty - widget.item.totalStock).toInt();
      if (diff != 0) {
        await database.inventoryDao.adjustStock(
          productId,
          warehouseId,
          diff,
          "Manual adjustment from Product Detail Screen",
          null, // staffId
        );
      }

      // 3. Update local item object (for UI feedback if staying on screen)
      setState(() {
        widget.item.productName = name;
        widget.item.manufacturer = manufacturer;
        widget.item.sellingPrice = selling;
        widget.item.buyingPrice = buying;
        widget.item.retailPrice = retail;
        widget.item.bulkBreakerPrice = bulk;
        widget.item.distributorPrice = distributor;
        // Warehouse stock updated via diff logic above, but for local:
        final wKey = widget.item.warehouseStock.keys.firstOrNull ?? 'w1';
        widget.item.warehouseStock[wKey] = newQty;
      });

      widget.onUpdateStock();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Delete Product', style: TextStyle(color: _text)),
        content: Text(
          'Are you sure you want to delete ${widget.item.productName}? This action cannot be undone.',
          style: TextStyle(color: _text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await database.catalogDao.softDeleteProduct(int.parse(widget.item.id));
              cartService.removeItem(widget.item.productName);
              if (!context.mounted) return;
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.item.productName} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: danger)),
          ),
        ],
      ),
    );
  }
}



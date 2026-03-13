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
import '../data/models/crate_stock.dart';
import '../data/models/inventory_log.dart';
import '../data/inventory_data.dart';
import '../../pos/data/products_data.dart';

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
  late TextEditingController _monthlyTargetController;
  int _monthlyTarget = 200; // Default or from item if it had one

  @override
  void initState() {
    super.initState();
    _monthlyTargetController = TextEditingController(text: _monthlyTarget.toString());
  }

  @override
  void dispose() {
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
    final isLow = widget.item.totalStock > 0 && widget.item.totalStock <= widget.item.lowStockThreshold;
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
                Text(
                  widget.item.productName,
                  style: TextStyle(
                    fontSize: context.getRFontSize(24),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: context.getRSize(6)),
                // Subtitle & status badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item.subtitle,
                      style: TextStyle(
                        fontSize: context.getRFontSize(14),
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

    final crateStock = supplier == null
        ? null
        : kCrateStocks.firstWhere(
            (c) => c.group == supplier!.crateGroup,
            orElse: () => CrateStock(group: CrateGroup.nbPlc),
          );
    final double totalStockValue = stockValue(
      (widget.item.sellingPrice ?? 0).toDouble(),
      widget.item.totalStock,
    );

    // Last delivery from logs
    final deliveryLogs =
        kInventoryLogs
            .where((l) => l.itemId == widget.item.id && l.action == 'restock')
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
              widget.item.totalStock.toStringAsFixed(widget.item.totalStock % 1 == 0 ? 0 : 1),
              blueMain,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(FontAwesomeIcons.circleMinus, size: context.getRSize(16), color: danger),
                    onPressed: () => _updateQuantity(-1),
                  ),
                  IconButton(
                    icon: Icon(FontAwesomeIcons.circlePlus, size: context.getRSize(16), color: success),
                    onPressed: () => _updateQuantity(1),
                  ),
                ],
              ),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.beerMugEmpty,
              'Empty Crates ${supplier != null ? "(${supplier.crateGroup.label})" : ""}',
              crateStock != null
                  ? '${crateStock.available.toInt()} available'
                  : 'N/A',
              supplier?.crateGroup.color ?? _subtext,
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
              formatCurrency(widget.item.sellingPrice ?? 0),
              success,
              onTap: () => _editPrice('sellingPrice'),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.dollarSign,
              'Buying Price',
              formatCurrency(widget.item.buyingPrice ?? 0),
              const Color(0xFFF59E0B),
              onTap: () => _editPrice('buyingPrice'),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.tag,
              'Retail Price',
              formatCurrency(widget.item.retailPrice ?? 0),
              blueMain,
              onTap: () => _editPrice('retailPrice'),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.users,
              'Bulk Breaker Price',
              formatCurrency(widget.item.bulkBreakerPrice ?? 0),
              const Color(0xFF8B5CF6),
              onTap: () => _editPrice('bulkBreakerPrice'),
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.truck,
              'Distributor Price',
              formatCurrency(widget.item.distributorPrice ?? 0),
              const Color(0xFFEC4899),
              onTap: () => _editPrice('distributorPrice'),
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
          _buildDeliveryCard(context, deliveryLogs, (widget.item.buyingPrice ?? 0).toInt()),

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
            icon: Icon(
              FontAwesomeIcons.trashCan,
              size: context.getRSize(16),
            ),
            label: Text(
              'Delete Product',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(16),
              ),
            ),
            onPressed: () => _confirmDelete(context),
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
    final int currentMonthly = 62;
    final int currentWeekly = 18;
    final int currentDaily = 4;

    return _infoCard(context, [
      _targetRow(context, 'Daily', currentDaily, _monthlyTarget ~/ 30),
      _divider(context),
      _targetRow(context, 'Weekly', currentWeekly, _monthlyTarget ~/ 4),
      _divider(context),
      _targetRow(context, 'Monthly', currentMonthly, _monthlyTarget, isEditable: true),
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
    List<InventoryLog> deliveryLogs,
    int buyingPrice,
  ) {
    if (deliveryLogs.isEmpty) {
      // Mock delivery data when no logs exist
      final mockDate = DateTime.now().subtract(const Duration(days: 3));
      final mockQty = 10;
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
    final qty = (last.newValue - last.previousValue).abs().toInt();
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                              child: Icon(Icons.close, color: _subtext, size: 18),
                            ),
                            title: Text('No Supplier', style: TextStyle(color: _text)),
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
                            child: Icon(FontAwesomeIcons.building, color: s.crateGroup.color, size: 16),
                          ),
                          title: Text(s.name, style: TextStyle(color: _text, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSelected ? Icon(Icons.check_circle, color: success) : null,
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

  void _updateQuantity(double delta) {
    setState(() {
      final warehouseId = widget.item.warehouseStock.keys.isNotEmpty
          ? widget.item.warehouseStock.keys.first
          : 'w1';
      final current = widget.item.warehouseStock[warehouseId] ?? 0;
      widget.item.warehouseStock[warehouseId] = current + delta;

      kInventoryLogs.add(
        InventoryLog(
          timestamp: DateTime.now(),
          user: 'John Cashier',
          itemId: widget.item.id,
          itemName: widget.item.productName,
          action: delta > 0 ? 'restock' : 'adjustment',
          previousValue: current,
          newValue: widget.item.warehouseStock[warehouseId]!,
          note: 'Direct manual adjustment from detail screen',
        ),
      );
    });
  }

  void _editPrice(String field) {
    final controller = TextEditingController(
      text: field == 'sellingPrice' ? (widget.item.sellingPrice ?? 0).toString() :
            field == 'buyingPrice' ? (widget.item.buyingPrice ?? 0).toString() :
            field == 'retailPrice' ? (widget.item.retailPrice ?? 0).toString() :
            field == 'bulkBreakerPrice' ? (widget.item.bulkBreakerPrice ?? 0).toString() :
            (widget.item.distributorPrice ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Edit ${field.replaceAll('Price', ' Price')}', style: TextStyle(color: _text)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _text),
          decoration: InputDecoration(
            hintText: 'Enter new price',
            hintStyle: TextStyle(color: _subtext),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                final newValue = double.tryParse(controller.text) ?? 0;
                if (field == 'sellingPrice') {
                  widget.item.sellingPrice = newValue;
                } else if (field == 'buyingPrice') {
                  widget.item.buyingPrice = newValue;
                } else if (field == 'retailPrice') {
                  widget.item.retailPrice = newValue;
                } else if (field == 'bulkBreakerPrice') {
                  widget.item.bulkBreakerPrice = newValue;
                } else if (field == 'distributorPrice') {
                  widget.item.distributorPrice = newValue;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                kInventoryItems.removeWhere((p) => p.id == widget.item.id);
                kProducts.removeWhere((p) => p['name'] == widget.item.productName);
              });
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

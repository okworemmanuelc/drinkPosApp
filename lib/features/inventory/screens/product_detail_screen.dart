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
                  child: Icon(
                    widget.item.icon,
                    color: Colors.white,
                    size: context.getRSize(36),
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
    final supplier = supplierService.getAll().firstWhere(
      (s) => s.id == widget.item.supplierId,
      orElse: () =>
          Supplier(id: '', name: 'Unknown', crateGroup: CrateGroup.nbPlc),
    );
    final crateStock = kCrateStocks.firstWhere(
      (c) => c.group == supplier.crateGroup,
      orElse: () => CrateStock(group: CrateGroup.nbPlc),
    );
    final product = kProducts.firstWhere(
      (p) => p['name'] == widget.item.productName,
      orElse: () => <String, dynamic>{},
    );
    final int sellingPrice = (product['sellingPrice'] as num?)?.toInt() ?? 0;
    final int buyingPrice = (product['bulkBreakerPrice'] as num?)?.toInt() ?? 0;
    final double totalStockValue = stockValue(
      sellingPrice.toDouble(),
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
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.beerMugEmpty,
              'Empty Crates (${supplier.crateGroup.label})',
              '${crateStock.available.toInt()} available',
              supplier.crateGroup.color,
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.buildingColumns,
              'Supplier',
              supplier.name,
              const Color(0xFF6366F1),
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
              formatCurrency(sellingPrice),
              success,
            ),
            _divider(context),
            _infoRow(
              context,
              FontAwesomeIcons.dollarSign,
              'Buying Price',
              formatCurrency(buyingPrice),
              const Color(0xFFF59E0B),
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
          _buildDeliveryCard(context, deliveryLogs, buyingPrice),

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
              FontAwesomeIcons.penToSquare,
              size: context.getRSize(16),
            ),
            label: Text(
              'Update Stock',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(16),
              ),
            ),
            onPressed: widget.onUpdateStock,
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
    Color iconColor,
  ) {
    return Padding(
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
          Flexible(
            child: Text(
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
          ),
        ],
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
          formatCurrency(buyingPrice),
        const Color(0xFFF59E0B),
      ),
      _divider(context),
      _infoRow(
        context,
        FontAwesomeIcons.receipt,
        'Total Delivery Cost',
        formatCurrency(buyingPrice * qty),
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
}

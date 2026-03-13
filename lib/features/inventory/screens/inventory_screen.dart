import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/services/navigation_service.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart'; // RESPONSIVE: utility imported
import '../data/models/crate_group.dart';
import '../data/models/supplier.dart';
import '../data/services/supplier_service.dart';
import '../data/models/inventory_item.dart';
import '../data/models/crate_stock.dart';
import '../data/models/inventory_log.dart';
import '../data/inventory_data.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../pos/data/products_data.dart';
import 'product_detail_screen.dart';
import 'supplier_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSupplierId = 'all';
  String _selectedWarehouseId = 'all';
  String _stockFilter = 'all'; // 'all' | 'low' | 'out' | 'empty_crates'

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Listen for cross-screen warehouse selection
    navigationService.selectedWarehouseId.addListener(_handleWarehouseNavigation);
  }

  void _handleWarehouseNavigation() {
    final id = navigationService.selectedWarehouseId.value;
    if (id != null) {
      setState(() {
        _selectedWarehouseId = id;
      });
      // Clear it so it doesn't trigger again on subsequent rebuilds/navigations unless set again
      navigationService.selectedWarehouseId.value = null;
    }
  }

  @override
  void dispose() {
    navigationService.selectedWarehouseId.removeListener(_handleWarehouseNavigation);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => SharedScaffold(
        activeRoute: 'inventory',
        backgroundColor: _bg,
        appBar: _buildAppBar(context),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSummaryCards(context), // RESPONSIVE: passing context
              _buildTabBar(context), // RESPONSIVE: passing context
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductsTab(context), // RESPONSIVE: passing context
                    _buildSuppliersTab(context), // RESPONSIVE: passing context
                    _buildCratesTab(context), // RESPONSIVE: passing context
                    _buildLogTab(context), // RESPONSIVE: passing context
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildAddFab(
          context,
        ), // RESPONSIVE: passing context
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: const MenuButton(),
      title: const AppBarHeader(
        icon: FontAwesomeIcons.boxesStacked,
        title: 'Inventory',
        subtitle: 'Stock Management',
      ),
      actions: const [NotificationBell(), SizedBox(width: AppSpacing.s)],
    );
  }

  // ── SUMMARY CARDS ─────────────────────────────────────────────────────────────
  Widget _buildSummaryCards(BuildContext context) {
    final filteredByWarehouse = _selectedWarehouseId == 'all'
        ? kInventoryItems
        : kInventoryItems.where((i) => i.warehouseStock.containsKey(_selectedWarehouseId)).toList();

    final totalItems = filteredByWarehouse.length;
    final lowStock = filteredByWarehouse
        .where((i) {
          final stock = _selectedWarehouseId == 'all' ? i.totalStock : i.getStockForWarehouse(_selectedWarehouseId);
          return stock <= i.lowStockThreshold;
        })
        .length;
    final outOfStock = filteredByWarehouse
        .where((i) {
          final stock = _selectedWarehouseId == 'all' ? i.totalStock : i.getStockForWarehouse(_selectedWarehouseId);
          return stock == 0;
        })
        .length;
    final totalCrates = _activeCrateGroups.fold<double>(
      0,
      (s, c) => s + c.available,
    );

    final cards = [
      _summaryCard(
        context,
        'Total SKUs',
        '$totalItems',
        FontAwesomeIcons.layerGroup,
        blueMain,
        isActive: _stockFilter == 'all',
        onTap: () => setState(() {
          _stockFilter = 'all';
          _tabController.animateTo(0);
        }),
      ),
      _summaryCard(
        context,
        'Low Stock',
        '$lowStock',
        FontAwesomeIcons.triangleExclamation,
        const Color(0xFFF59E0B),
        isActive: _stockFilter == 'low',
        onTap: () => setState(() {
          _stockFilter = 'low';
          _tabController.animateTo(0);
        }),
      ),
      _summaryCard(
        context,
        'Out of Stock',
        '$outOfStock',
        FontAwesomeIcons.ban,
        danger,
        isActive: _stockFilter == 'out',
        onTap: () => setState(() {
          _stockFilter = 'out';
          _tabController.animateTo(0);
        }),
      ),
      _summaryCard(
        context,
        'Empty Crates',
        '${totalCrates.toInt()}',
        FontAwesomeIcons.beerMugEmpty,
        success,
        isActive: _tabController.index == 2,
        onTap: () => setState(() {
          _tabController.animateTo(2);
        }),
      ),
    ];

    return Container(
      color: _surface,
      padding: EdgeInsets.only(
        top: context.getRSize(12),
        bottom: context.getRSize(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingM,
      ),
        child: Row(
          children: cards.asMap().entries.map((entry) {
            final int index = entry.key;
            final Widget card = entry.value;
            return Container(
              // Allow cards to scroll naturally with a fixed width
              width: context.isPhone
                  ? context.getRSize(130)
                  : context.getRSize(180),
              margin: EdgeInsets.only(
                right: index < cards.length - 1 ? context.getRSize(12) : 0,
              ),
              child: card,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    // RESPONSIVE: Removed Expanded wrapper so it can be sized externally by Wrap or Row
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.spacingM),
        decoration: BoxDecoration(
          color: _isDark ? dCard : lCard,
          borderRadius: BorderRadius.circular(context.radiusM),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: context.getRSize(16),
              color: color,
            ), // RESPONSIVE: scaled icon
            SizedBox(height: context.getRSize(8)),
            FittedBox(
              // RESPONSIVE: Text scales dynamically
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: rFontSize(context, 20), // RESPONSIVE: scaled font
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
            ),
            SizedBox(height: context.spacingS),
            Text(
              label,
              style: context.bodySmall.copyWith(
                color: _subtext,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Divider(height: 1, color: _border),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: blueMain,
            unselectedLabelColor: _subtext,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: context.getRFontSize(13), // RESPONSIVE
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: context.getRFontSize(13), // RESPONSIVE
            ),
            indicatorColor: blueMain,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Suppliers'),
              Tab(text: 'Empty Crates'),
              Tab(text: 'Activity Log'),
            ],
          ),
        ],
      ),
    );
  }

  // ── PRODUCTS TAB ──────────────────────────────────────────────────────────────
  Widget _buildProductsTab(BuildContext context) {
    return Column(
      children: [
        _buildSupplierFilter(context),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              context.getRSize(16),
              context.getRSize(12),
              context.getRSize(16),
              context.getRSize(120),
            ), // RESPONSIVE
            itemCount: _filteredItems.length,
            itemBuilder: (_, i) => _buildProductRow(context, _filteredItems[i]),
          ),
        ),
      ],
    );
  }

  // ── SUPPLIERS TAB ─────────────────────────────────────────────────────────────
  Widget _buildSuppliersTab(BuildContext context) {
    return Column(
      children: [
        // Non-floating "+" button at the top of the tab
        Padding(
          padding: EdgeInsets.all(context.getRSize(16)),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain.withValues(alpha: 0.1),
                foregroundColor: blueMain,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: blueMain.withValues(alpha: 0.3)),
                ),
              ),
              icon: Icon(FontAwesomeIcons.plus, size: context.getRSize(16)),
              label: Text(
                'Add Supplier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(15),
                ),
              ),
              onPressed: _showAddSupplierDialog,
            ),
          ),
        ),
        // Supplier List
        Expanded(
          child: supplierService.getAll().isEmpty
              ? Center(
                  child: Text(
                    'No suppliers added yet',
                    style: TextStyle(color: _subtext),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.getRSize(16),
                    0,
                    context.getRSize(16),
                    context.getRSize(120),
                  ),
                  itemCount: supplierService.getAll().length,
                  itemBuilder: (_, i) {
                    final s = supplierService.getAll()[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierDetailScreen(supplier: s),
                        ),
                      ).then((_) => setState(() {})),
                      child: Container(
                        margin: EdgeInsets.only(bottom: context.getRSize(12)),
                        padding: EdgeInsets.all(context.getRSize(16)),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: context.getRSize(48),
                              height: context.getRSize(48),
                              decoration: BoxDecoration(
                                color: blueMain.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.buildingColumns,
                                color: blueMain,
                                size: context.getRSize(20),
                              ),
                            ),
                            SizedBox(width: context.getRSize(16)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: context.getRFontSize(16),
                                      color: _text,
                                    ),
                                  ),
                                  if (s.contactDetails.isNotEmpty) ...[
                                    SizedBox(height: context.getRSize(4)),
                                    Text(
                                      s.contactDetails,
                                      style: TextStyle(
                                        color: _subtext,
                                        fontSize: context.getRFontSize(13),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: _subtext,
                              size: context.getRSize(20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<InventoryItem> get _filteredItems {
    var list = _selectedSupplierId == 'all'
        ? kInventoryItems
        : kInventoryItems
              .where((i) => i.supplierId == _selectedSupplierId)
              .toList();

    if (_selectedWarehouseId != 'all') {
      list = list.where((i) => i.warehouseStock.containsKey(_selectedWarehouseId)).toList();
    }

    if (_stockFilter == 'low') {
      return list
          .where((i) {
            final stock = _selectedWarehouseId == 'all' ? i.totalStock : i.getStockForWarehouse(_selectedWarehouseId);
            return stock > 0 && stock <= i.lowStockThreshold;
          })
          .toList();
    } else if (_stockFilter == 'out') {
      return list.where((i) {
        final stock = _selectedWarehouseId == 'all' ? i.totalStock : i.getStockForWarehouse(_selectedWarehouseId);
        return stock == 0;
      }).toList();
    }
    return list;
  }

  List<CrateStock> get _activeCrateGroups {
    // 1. Get all unique crate groups used by current inventory items
    final Set<CrateGroup> usedGroups = {};
    for (final item in kInventoryItems) {
      final isGlass = item.subtitle.toLowerCase() == 'crate';
      if (!isGlass) continue;

      if (item.supplierId == null) continue;

      final supplier = supplierService.getById(item.supplierId!);
      if (supplier != null) {
        usedGroups.add(supplier.crateGroup);
      }
    }

    // 2. Filter kCrateStocks by those groups
    return kCrateStocks.where((cs) => usedGroups.contains(cs.group)).toList();
  }

  Widget _buildSupplierFilter(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(12),
        context.getRSize(16),
        context.getRSize(16),
      ),
      color: _surface,
      child: Row(
        children: [
          // Warehouse Dropdown
          Expanded(
            child: _buildFilterDropdown(
              label: 'Warehouse',
              value: _selectedWarehouseId,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Warehouses')),
                ...kWarehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (val) => setState(() => _selectedWarehouseId = val!),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          // Supplier Dropdown
          Expanded(
            child: _buildFilterDropdown(
              label: 'Supplier',
              value: _selectedSupplierId,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Suppliers')),
                ...supplierService.getAll().map(
                  (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                ),
              ],
              onChanged: (val) => setState(() => _selectedSupplierId = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(11),
            fontWeight: FontWeight.w700,
            color: _subtext,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: context.getRSize(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.getRSize(12)),
          decoration: BoxDecoration(
            color: _isDark ? dCard : lCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              alignment: AlignmentDirectional.bottomStart,
              menuMaxHeight: 350,
              icon: Icon(Icons.keyboard_arrow_down, color: blueMain, size: context.getRSize(18)),
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.w600,
                color: _text,
              ),
              dropdownColor: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(BuildContext context, InventoryItem item) {
    final currentStock = _selectedWarehouseId == 'all' ? item.totalStock : item.getStockForWarehouse(_selectedWarehouseId);
    final isLow = currentStock > 0 && currentStock <= item.lowStockThreshold;
    final isOut = currentStock == 0;
    final supplier = item.supplierId == null
        ? null
        : supplierService.getAll().cast<Supplier?>().firstWhere(
            (s) => s?.id == item.supplierId,
            orElse: () => null,
          );
    final crateStock = supplier == null
        ? null
        : kCrateStocks.firstWhere(
            (c) => c.group == supplier.crateGroup,
            orElse: () => CrateStock(group: CrateGroup.nbPlc),
          );

    Color statusColor = success;
    String statusLabel = 'In Stock';
    if (isOut) {
      statusColor = danger;
      statusLabel = 'Out of Stock';
    } else if (isLow) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Low Stock';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            item: item,
            onUpdateStock: () => _showUpdateStockDialog(item),
          ),
        ),
      ).then((_) => setState(() {})), // refresh after returning
      child: Container(
        margin: EdgeInsets.only(bottom: context.spacingS),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOut
                ? danger.withValues(alpha: 0.3)
                : isLow
                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                : _border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(
            context.isPhone ? context.getRSize(10) : context.getRSize(14),
          ), // RESPONSIVE
          child: Row(
            children: [
              Container(
                width: context.getRSize(52), // RESPONSIVE
                height: context.getRSize(52), // RESPONSIVE
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: context.getRSize(24),
                ), // RESPONSIVE
              ),
              SizedBox(width: context.getRSize(14)), // RESPONSIVE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.productName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15), // RESPONSIVE
                              color: _text,
                            ),
                          ),
                        ),
                        SizedBox(width: context.getRSize(8)), // RESPONSIVE
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.getRSize(8),
                            vertical: context.getRSize(2),
                          ), // RESPONSIVE
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: context.getRFontSize(10), // RESPONSIVE
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.getRSize(4)), // RESPONSIVE
                    Text(
                      supplier?.name ?? 'Not Assigned',
                      style: TextStyle(
                        fontSize: context.getRFontSize(12),
                        color: _subtext,
                      ), // RESPONSIVE
                    ),
                    SizedBox(height: context.getRSize(6)), // RESPONSIVE
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.beerMugEmpty,
                          size: context.getRSize(10), // RESPONSIVE
                          color: supplier?.crateGroup.color ?? _subtext,
                        ),
                        SizedBox(width: context.getRSize(4)), // RESPONSIVE
                        Expanded(
                          child: Text(
                            supplier != null && crateStock != null
                                ? 'Empty crates (${supplier.crateGroup.label}): ${crateStock.available.toInt()} available'
                                : 'Empty crates: Not tracked',
                            style: TextStyle(
                              fontSize: context.getRFontSize(11),
                              color: _subtext,
                            ), // RESPONSIVE
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    // RESPONSIVE: Prevent quantity overflow
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currentStock.toStringAsFixed(currentStock % 1 == 0 ? 0 : 1),
                      style: TextStyle(
                        fontSize: context.getRFontSize(22), // RESPONSIVE
                        fontWeight: FontWeight.w800,
                        color: isOut
                            ? danger
                            : isLow
                            ? const Color(0xFFF59E0B)
                            : _text,
                      ),
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: _subtext,
                    ), // RESPONSIVE
                  ),
                  SizedBox(height: context.getRSize(4)), // RESPONSIVE
                  Icon(
                    FontAwesomeIcons.penToSquare,
                    size: context.getRSize(12),
                    color: blueMain,
                  ), // RESPONSIVE
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CRATES TAB ────────────────────────────────────────────────────────────────
  Widget _buildCratesTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(100),
      ), // RESPONSIVE
      children: [
        Container(
          padding: EdgeInsets.all(context.getRSize(16)), // RESPONSIVE
          decoration: BoxDecoration(
            color: _isDark ? dCard : lCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.circleInfo,
                    size: context.getRSize(14), // RESPONSIVE
                    color: blueMain,
                  ),
                  SizedBox(width: context.getRSize(8)), // RESPONSIVE
                  Expanded(
                    child: Text(
                      'How Empty Crates Work',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(14), // RESPONSIVE
                        color: _text,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.getRSize(8)), // RESPONSIVE
              Text(
                'Empty crates are pooled by supplier group — all bottles from the same group share the same crate type. When a customer returns crates, add them to the relevant group. When restocking a product, crates are drawn from that group.',
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  color: _subtext,
                  height: 1.5,
                ), // RESPONSIVE
              ),
            ],
          ),
        ),
        SizedBox(height: context.getRSize(16)), // RESPONSIVE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Crate Groups',
                style: TextStyle(
                  fontSize: context.getRFontSize(16), // RESPONSIVE
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showAddCrateGroupDialog,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(12),
                  vertical: context.getRSize(6),
                ), // RESPONSIVE
                decoration: BoxDecoration(
                  color: blueMain.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FontAwesomeIcons.plus,
                      size: context.getRSize(12),
                      color: blueMain,
                    ), // RESPONSIVE
                    SizedBox(width: context.getRSize(6)), // RESPONSIVE
                    Text(
                      'New Group',
                      style: TextStyle(
                        fontSize: context.getRFontSize(12), // RESPONSIVE
                        fontWeight: FontWeight.bold,
                        color: blueMain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.getRSize(12)), // RESPONSIVE
        ..._activeCrateGroups.map((cs) => _buildCrateGroupCard(context, cs)),
      ],
    );
  }

  Widget _buildCrateGroupCard(BuildContext context, CrateStock cs) {
    final linkedProducts = kInventoryItems
        .where((item) {
          if (item.supplierId == null) return false;
          final supplier = supplierService.getAll().cast<Supplier?>().firstWhere(
            (s) => s?.id == item.supplierId,
            orElse: () => null,
          );
          return supplier?.crateGroup == cs.group;
        })
        .map((i) => i.productName)
        .toList();

    final linkedSuppliers = supplierService
        .getAll()
        .where((s) => s.crateGroup == cs.group)
        .map((s) => s.name)
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)), // RESPONSIVE
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.getRSize(16)), // RESPONSIVE
            child: Row(
              children: [
                Container(
                  width: context.getRSize(48), // RESPONSIVE
                  height: context.getRSize(48), // RESPONSIVE
                  decoration: BoxDecoration(
                    color: cs.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    FontAwesomeIcons.beerMugEmpty,
                    color: cs.color,
                    size: context.getRSize(22), // RESPONSIVE
                  ),
                ),
                SizedBox(width: context.getRSize(14)), // RESPONSIVE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cs.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(16), // RESPONSIVE
                          color: _text,
                        ),
                      ),
                      SizedBox(height: context.getRSize(4)), // RESPONSIVE
                      Text(
                        linkedSuppliers.isEmpty
                            ? 'No suppliers linked'
                            : linkedSuppliers.join(', '),
                        style: TextStyle(
                          fontSize: context.getRFontSize(12),
                          color: _subtext,
                        ), // RESPONSIVE
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      // RESPONSIVE: Prevent quantity overflow
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${cs.available.toInt()}',
                        style: TextStyle(
                          fontSize: context.getRFontSize(28), // RESPONSIVE
                          fontWeight: FontWeight.w800,
                          color: cs.available == 0 ? danger : _text,
                        ),
                      ),
                    ),
                    Text(
                      'crates',
                      style: TextStyle(
                        fontSize: context.getRFontSize(11),
                        color: _subtext,
                      ), // RESPONSIVE
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (linkedProducts.isNotEmpty) ...[
            Divider(height: 1, color: _border),
            Padding(
              padding: EdgeInsets.fromLTRB(
                // RESPONSIVE
                context.getRSize(16),
                context.getRSize(10),
                context.getRSize(16),
                context.getRSize(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked Products: ',
                    style: TextStyle(
                      fontSize: context.getRFontSize(12), // RESPONSIVE
                      fontWeight: FontWeight.bold,
                      color: _subtext,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      linkedProducts.join(', '),
                      style: TextStyle(
                        fontSize: context.getRFontSize(12),
                        color: _subtext,
                      ), // RESPONSIVE
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showUpdateCratesDialog(cs),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(12),
                        vertical: context.getRSize(5),
                      ), // RESPONSIVE
                      decoration: BoxDecoration(
                        color: cs.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          fontSize: context.getRFontSize(11), // RESPONSIVE
                          fontWeight: FontWeight.bold,
                          color: cs.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── LOG TAB ───────────────────────────────────────────────────────────────────
  Widget _buildLogTab(BuildContext context) {
    if (kInventoryLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.clockRotateLeft,
              size: context.getRSize(48),
              color: _border,
            ), // RESPONSIVE
            SizedBox(height: context.getRSize(16)), // RESPONSIVE
            Text(
              'No activity yet',
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(16), // RESPONSIVE
              ),
            ),
            SizedBox(height: context.getRSize(6)), // RESPONSIVE
            Text(
              'Updates will appear here with date, time, and user',
              style: TextStyle(
                color: _subtext,
                fontSize: context.getRFontSize(13),
              ), // RESPONSIVE
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sorted = [...kInventoryLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(100),
      ), // RESPONSIVE
      itemCount: sorted.length,
      separatorBuilder: (_, _) =>
          SizedBox(height: context.getRSize(8)), // RESPONSIVE
      itemBuilder: (_, i) => _buildLogRow(context, sorted[i]),
    );
  }

  Widget _buildLogRow(BuildContext context, InventoryLog log) {
    final actionColors = {
      'restock': success,
      'adjustment': blueMain,
      'crate_update': const Color(0xFFF59E0B),
      'new_supplier': const Color(0xFF8B5CF6),
    };
    final color = actionColors[log.action] ?? blueMain;
    final diff = log.newValue - log.previousValue;
    final diffStr = diff >= 0
        ? '+${diff.toStringAsFixed(1)}'
        : diff.toStringAsFixed(1);

    return Container(
      padding: EdgeInsets.all(context.getRSize(14)), // RESPONSIVE
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: context.getRSize(42), // RESPONSIVE
            height: context.getRSize(42), // RESPONSIVE
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              log.action == 'restock'
                  ? FontAwesomeIcons.arrowUp
                  : log.action == 'crate_update'
                  ? FontAwesomeIcons.beerMugEmpty
                  : log.action == 'new_supplier'
                  ? FontAwesomeIcons.buildingColumns
                  : FontAwesomeIcons.pen,
              size: context.getRSize(16), // RESPONSIVE
              color: color,
            ),
          ),
          SizedBox(width: context.getRSize(12)), // RESPONSIVE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14), // RESPONSIVE
                    color: _text,
                  ),
                ),
                SizedBox(height: context.getRSize(2)), // RESPONSIVE
                Text(
                  '${log.user} · ${_formatLogTime(log.timestamp)}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11),
                    color: _subtext,
                  ), // RESPONSIVE
                ),
                if (log.note != null) ...[
                  SizedBox(height: context.getRSize(2)), // RESPONSIVE
                  Text(
                    log.note!,
                    style: TextStyle(
                      fontSize: context.getRFontSize(11), // RESPONSIVE
                      color: _subtext,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                diffStr,
                style: TextStyle(
                  fontSize: context.getRFontSize(16), // RESPONSIVE
                  fontWeight: FontWeight.w800,
                  color: diff >= 0 ? success : danger,
                ),
              ),
              Text(
                '${log.previousValue.toInt()} → ${log.newValue.toInt()}',
                style: TextStyle(
                  fontSize: context.getRFontSize(10),
                  color: _subtext,
                ), // RESPONSIVE
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLogTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── FAB ───────────────────────────────────────────────────────────────────────
  Widget _buildAddFab(BuildContext context) {
    return Hero(
      tag: 'inventory_fab',
      child: GestureDetector(
        onTap: _showAddProductDialog,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(20),
            vertical: context.getRSize(14),
          ), // RESPONSIVE
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [blueLight, blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: blueMain.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.plus,
                color: Colors.white,
                size: context.getRSize(16),
              ), // RESPONSIVE
              SizedBox(width: context.getRSize(10)), // RESPONSIVE
              Text(
                'Add Product',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: context.getRFontSize(13), // RESPONSIVE
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UPDATE STOCK DIALOG ───────────────────────────────────────────────────────
  void _showUpdateStockDialog(InventoryItem item) {
    final ctrl = TextEditingController(text: '');
    final noteCtrl = TextEditingController();
    String action = 'restock';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ctx.getRSize(20),
                    ctx.getRSize(20),
                    ctx.getRSize(20),
                    0,
                  ), // RESPONSIVE
                  child: Center(
                    child: Container(
                      width: ctx.getRSize(40), // RESPONSIVE
                      height: ctx.getRSize(4), // RESPONSIVE
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)), // RESPONSIVE
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.getRSize(20),
                    ), // RESPONSIVE
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: ctx.getRSize(44), // RESPONSIVE
                              height: ctx.getRSize(44), // RESPONSIVE
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: ctx.getRSize(20),
                              ), // RESPONSIVE
                            ),
                            SizedBox(width: ctx.getRSize(14)), // RESPONSIVE
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    // RESPONSIVE
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Update Stock',
                                      style: TextStyle(
                                        fontSize: ctx.getRFontSize(
                                          18,
                                        ), // RESPONSIVE
                                        fontWeight: FontWeight.w800,
                                        color: _text,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item.productName,
                                    style: TextStyle(
                                      fontSize: ctx.getRFontSize(
                                        13,
                                      ), // RESPONSIVE
                                      color: blueMain,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ctx.getRSize(20)), // RESPONSIVE
                        Text(
                          'Action',
                          style: TextStyle(
                            fontSize: ctx.getRFontSize(12), // RESPONSIVE
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        SizedBox(height: ctx.getRSize(8)), // RESPONSIVE
                        Row(
                          children: [
                            Expanded(
                              // RESPONSIVE: use Expanded to fit buttons evenly
                              child: _actionChip(
                                ctx,
                                'restock',
                                'Restock',
                                action,
                                (v) => setB(() => action = v),
                              ),
                            ),
                            SizedBox(width: ctx.getRSize(8)), // RESPONSIVE
                            Expanded(
                              // RESPONSIVE: use Expanded
                              child: _actionChip(
                                ctx,
                                'adjustment',
                                'Adjust',
                                action,
                                (v) => setB(() => action = v),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ctx.getRSize(16)), // RESPONSIVE
                        Text(
                          action == 'restock'
                              ? 'Quantity to Add'
                              : 'Set Stock To',
                          style: TextStyle(
                            fontSize: ctx.getRFontSize(12), // RESPONSIVE
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        SizedBox(height: ctx.getRSize(8)), // RESPONSIVE
                        TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                          decoration: InputDecoration(
                            hintText: action == 'restock'
                                ? 'e.g. 10 (will be added to current stock)'
                                : 'e.g. 18 (replaces current stock)',
                            hintStyle: TextStyle(color: _subtext),
                            filled: true,
                            fillColor: _isDark ? dCard : lCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: blueMain,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            suffixText: item.subtitle,
                            suffixStyle: TextStyle(
                              color: _subtext,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteCtrl,
                          style: TextStyle(fontSize: 14, color: _text),
                          decoration: InputDecoration(
                            hintText: 'Note (optional)',
                            hintStyle: TextStyle(color: _subtext),
                            filled: true,
                            fillColor: _isDark ? dCard : lCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: blueMain,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showUpdatePriceDialog(item);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FontAwesomeIcons.tag,
                                  size: 14,
                                  color: success,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Update Price',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Pad the bottom of the scroll view
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueMain,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final entered = double.tryParse(ctrl.text) ?? 0;
                        // For now, we update the first warehouse available
                        final warehouseId = item.warehouseStock.keys.isNotEmpty 
                            ? item.warehouseStock.keys.first 
                            : 'w1';
                        final currentWarehouseStock = item.warehouseStock[warehouseId] ?? 0.0;
                        
                        final newWarehouseQty = action == 'restock'
                            ? currentWarehouseStock + entered
                            : entered;
                        final diff = newWarehouseQty - currentWarehouseStock;

                        final log = InventoryLog(
                          timestamp: DateTime.now(),
                          user: 'John Cashier',
                          itemId: item.id,
                          itemName: item.productName,
                          action: action,
                          previousValue: item.totalStock,
                          newValue: item.totalStock + diff,
                          note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                        );

                        // Adjust crate stock if it's a "Glass Crates" product
                        // 1. Check product category
                        final productData = kProducts.firstWhere(
                          (p) => p['name'] == item.productName,
                          orElse: () => <String, dynamic>{},
                        );

                        setState(() {
                          // Update the specific warehouse stock
                          final newStockMap = Map<String, double>.from(item.warehouseStock);
                          newStockMap[warehouseId] = newWarehouseQty;
                          item.warehouseStock = newStockMap;
                          
                          kInventoryLogs.add(log);

                          if (productData.isNotEmpty &&
                              productData['category'] == 'Glass Crates') {
                            final supplier = item.supplierId == null
                                ? null
                                : supplierService.getAll().cast<Supplier?>().firstWhere(
                                      (s) => s?.id == item.supplierId,
                                      orElse: () => null,
                                    );

                            final cStockIndex = supplier == null
                                ? -1
                                : kCrateStocks.indexWhere(
                                    (c) => c.group == supplier.crateGroup,
                                  );

                            if (cStockIndex != -1) {
                              kCrateStocks[cStockIndex].available += diff;
                            }
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Save Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UPDATE PRICE DIALOG ───────────────────────────────────────────────────────
  void _showUpdatePriceDialog(InventoryItem item) {
    final existingParams = kProducts.firstWhere(
      (p) => p['name'] == item.productName,
      orElse: () => {'price': 0, 'wholesale_price': 0, 'category': 'Other'},
    );
    final priceCtrl = TextEditingController(
      text: (existingParams['price'] ?? 0).toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.tag,
                                color: success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update Price',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: blueMain,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Retail Selling Price (₦)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            fontSize: ctx.getRFontSize(18), // RESPONSIVE
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter price (e.g. 5000)',
                            hintStyle: TextStyle(color: _subtext),
                            filled: true,
                            fillColor: _isDark ? dCard : lCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: blueMain,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.all(
                              ctx.getRSize(16),
                            ), // RESPONSIVE
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ctx.getRSize(20),
                    ctx.getRSize(24),
                    ctx.getRSize(20),
                    ctx.getRSize(32),
                  ), // RESPONSIVE
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: ctx.getRSize(16),
                        ), // RESPONSIVE
                        elevation: 0,
                      ),
                      onPressed: () {
                        final newPrice =
                            int.tryParse(priceCtrl.text) ??
                            existingParams['price'];
                        setState(() {
                          final idx = kProducts.indexWhere(
                            (p) => p['name'] == item.productName,
                          );
                          if (idx != -1) {
                            kProducts[idx]['price'] = newPrice;
                          } else {
                            kProducts.add({
                              'name': item.productName,
                              'subtitle': item.subtitle,
                              'price': newPrice,
                              'wholesale_price': newPrice, // fallback
                              'category': 'Other', // fallback
                              'icon': item.icon,
                              'color': item.color,
                            });
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Save Price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, // RESPONSIVE: pass context
    String value,
    String label,
    String current,
    Function(String) onTap,
  ) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.getRSize(20),
          vertical: context.getRSize(10),
        ), // RESPONSIVE
        decoration: BoxDecoration(
          color: active ? blueMain : (_isDark ? dCard : lCard),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? blueMain : _border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: context.getRFontSize(13), // RESPONSIVE
              color: active ? Colors.white : _subtext,
            ),
          ),
        ),
      ),
    );
  }

  // ── UPDATE CRATES DIALOG ──────────────────────────────────────────────────────
  void _showUpdateCratesDialog(CrateStock cs) {
    final ctrl = TextEditingController(text: cs.available.toInt().toString());
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: _isDark ? dSurface : lSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.group.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              FontAwesomeIcons.beerMugEmpty,
                              color: cs.group.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Empty Crates',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _text,
                                ),
                              ),
                              Text(
                                cs.group.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.group.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Available Empty Crates',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _subtext,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Number of crates',
                          hintStyle: TextStyle(color: _subtext),
                          filled: true,
                          fillColor: _isDark ? dCard : lCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: blueMain,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          suffixText: 'crates',
                          suffixStyle: TextStyle(color: _subtext, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        style: TextStyle(fontSize: 14, color: _text),
                        decoration: InputDecoration(
                          hintText: 'Note e.g. "Customer returned 10 crates"',
                          hintStyle: TextStyle(color: _subtext),
                          filled: true,
                          fillColor: _isDark ? dCard : lCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: blueMain,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.group.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final newQty = double.tryParse(ctrl.text) ?? cs.available;
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: 'crate_${cs.group.name}',
                        itemName: '${cs.group.label} Crates',
                        action: 'crate_update',
                        previousValue: cs.available,
                        newValue: newQty,
                        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                      );
                      setState(() {
                        cs.available = newQty;
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Save Update',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ADD PRODUCT DIALOG ────────────────────────────────────────────────────────
  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    String? selectedSupplierId;
    final stockCtrl = TextEditingController(text: '0');
    final retailPriceCtrl = TextEditingController();
    final bulkBreakerPriceCtrl = TextEditingController();
    final distributorPriceCtrl = TextEditingController();
    String selectedCategory = 'Other';
    CrateGroup? selectedCrateGroup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add New Product',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product will be added to inventory tracking',
                        style: TextStyle(fontSize: 13, color: _subtext),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputField(
                          'Product Name',
                          nameCtrl,
                          'e.g. Trophy Lager',
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          'Type / Packaging',
                          subtitleCtrl,
                          'e.g. Crate, Can, Keg',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isDark ? dCard : lCard,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory,
                              dropdownColor: _isDark ? dCard : lSurface,
                              style: TextStyle(
                                color: _text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              isExpanded: true,
                              onChanged: (v) => setB(() => selectedCategory = v!),
                              items: ['Glass Crates', 'Cans & PET', 'Kegs', 'Other'].map(
                                (c) => DropdownMenuItem(value: c, child: Text(c)),
                              ).toList(),
                            ),
                          ),
                        ),
                        if (selectedCategory == 'Glass Crates') ...[
                          const SizedBox(height: 12),
                          Text(
                            'Pair with Empty Crate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _subtext,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: _isDark ? dCard : lCard,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<CrateGroup>(
                                value: selectedCrateGroup,
                                dropdownColor: _isDark ? dCard : lSurface,
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                isExpanded: true,
                                hint: Text('Select Crate Group', style: TextStyle(color: _subtext, fontSize: 14)),
                                onChanged: (v) => setB(() => selectedCrateGroup = v),
                                items: CrateGroup.values.map(
                                  (cg) => DropdownMenuItem(value: cg, child: Text(cg.label)),
                                ).toList(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Supplier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isDark ? dCard : lCard,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedSupplierId,
                              dropdownColor: _isDark ? dCard : lSurface,
                              style: TextStyle(
                                color: _text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              isExpanded: true,
                              hint: Text(
                                'Select Supplier (Optional)',
                                style: TextStyle(
                                  color: _subtext,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: (v) =>
                                  setB(() => selectedSupplierId = v),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'No Supplier / Pair Later',
                                    style: TextStyle(color: _subtext),
                                  ),
                                ),
                                ...supplierService.getAll().map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          'Initial Stock',
                          stockCtrl,
                          'e.g. 50',
                          isNumber: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _inputField(
                                'Retail Price',
                                retailPriceCtrl,
                                'e.g. 500',
                                isNumber: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _inputField(
                                'Bulk Breaker',
                                bulkBreakerPriceCtrl,
                                'e.g. 450',
                                isNumber: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          'Distributor Price',
                          distributorPriceCtrl,
                          'e.g. 420',
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueMain,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final newItem = InventoryItem(
                          id: 'i${DateTime.now().millisecondsSinceEpoch}',
                          productName: nameCtrl.text.trim(),
                          subtitle: subtitleCtrl.text.trim().isEmpty
                              ? 'Unit'
                              : subtitleCtrl.text.trim(),
                          supplierId: selectedSupplierId,
                          icon: FontAwesomeIcons.wineBottle,
                          color: blueMain,
                          warehouseStock: {
                            'w1': double.tryParse(stockCtrl.text) ?? 0
                          },
                          category: selectedCategory,
                          retailPrice: double.tryParse(retailPriceCtrl.text),
                          bulkBreakerPrice: double.tryParse(bulkBreakerPriceCtrl.text),
                          distributorPrice: double.tryParse(distributorPriceCtrl.text),
                          sellingPrice: double.tryParse(retailPriceCtrl.text), // Use retail as default selling
                          needsEmptyCrate: selectedCategory == 'Glass Crates',
                          crateGroupName: selectedCrateGroup?.label,
                        );
                        final log = InventoryLog(
                          timestamp: DateTime.now(),
                          user: 'John Cashier',
                          itemId: newItem.id,
                          itemName: newItem.productName,
                          action: 'restock',
                          previousValue: 0,
                          newValue: newItem.totalStock,
                          note: 'New product added to inventory',
                        );
                        setState(() {
                          kInventoryItems.add(newItem);
                          kInventoryLogs.add(log);

                          // Also add to POS products data
                          kProducts.add({
                            'name': newItem.productName,
                            'subtitle': newItem.subtitle,
                            'category': selectedCategory,
                            'sellingPrice': newItem.sellingPrice ?? 0,
                            'retailPrice': newItem.retailPrice ?? 0,
                            'bulkBreakerPrice': newItem.bulkBreakerPrice ?? 0,
                            'distributorPrice': newItem.distributorPrice ?? 0,
                            'icon': newItem.icon,
                            'color': newItem.color,
                            'image': '',
                          });
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Add to Inventory & POS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(fontSize: 14, color: _text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _subtext),
            filled: true,
            fillColor: _isDark ? dCard : lCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: blueMain, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ── ADD SUPPLIER DIALOG ───────────────────────────────────────────────────────
  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                Text(
                  'Add New Supplier',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                SizedBox(height: ctx.getRSize(4)),
                Text(
                  'Enter the company and contact details',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(13),
                    color: _subtext,
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                _inputField(
                  'Supplier / Company Name',
                  nameCtrl,
                  'e.g. SABMiller Nigeria',
                ),
                SizedBox(height: ctx.getRSize(16)),
                _inputField(
                  'Contact Details / Rep Info',
                  contactCtrl,
                  'e.g. John Doe, 08012345678',
                ),
                SizedBox(height: ctx.getRSize(32)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ctx.getRSize(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final newSupplier = Supplier(
                        id: 's${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        crateGroup: CrateGroup.nbPlc, // Default hidden value
                        trackInventory: true,
                        contactDetails: contactCtrl.text.trim(),
                        amountPaid: 0.0,
                        supplierWallet: 0.0,
                      );
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: newSupplier.id,
                        itemName: newSupplier.name,
                        action: 'new_supplier',
                        previousValue: 0,
                        newValue: 0,
                        note: 'Supplier added: ${newSupplier.name}',
                      );
                      setState(() {
                        supplierService.addSupplier(newSupplier);
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ctx.getRFontSize(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ADD CRATE GROUP DIALOG ──────────────────────────────────────────────────
  void _showAddCrateGroupDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');

    // Palette of colors for new custom groups
    const groupColors = [
      Color(0xFF6366F1), // indigo
      Color(0xFF0EA5E9), // sky blue
      Color(0xFF14B8A6), // teal
      Color(0xFFF97316), // orange
      Color(0xFFEC4899), // pink
      Color(0xFF8B5CF6), // violet
      Color(0xFF22C55E), // green
      Color(0xFFEF4444), // red
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(20),
              ctx.getRSize(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                Text(
                  'Add Crate Group',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                SizedBox(height: ctx.getRSize(4)),
                Text(
                  'Enter a name for the new crate group and set the initial count',
                  style: TextStyle(
                    fontSize: ctx.getRFontSize(13),
                    color: _subtext,
                  ),
                ),
                SizedBox(height: ctx.getRSize(20)),
                // Crate Group Name input
                _inputField(
                  'Crate Group Name',
                  nameCtrl,
                  'e.g. SABMiller, Diageo',
                ),
                SizedBox(height: ctx.getRSize(16)),
                // Initial quantity
                _inputField('Initial Quantity', qtyCtrl, '0', isNumber: true),
                SizedBox(height: ctx.getRSize(24)),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ctx.getRSize(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      // Pick a color from the palette based on the current count
                      final colorIndex =
                          kCrateStocks.length % groupColors.length;
                      setState(() {
                        kCrateStocks.add(
                          CrateStock(
                            group: CrateGroup.values.first,
                            available: qty,
                            customLabel: name,
                            customColor: groupColors[colorIndex],
                          ),
                        );
                        kInventoryLogs.add(
                          InventoryLog(
                            timestamp: DateTime.now(),
                            user: 'John Cashier',
                            itemId:
                                'cg_${DateTime.now().millisecondsSinceEpoch}',
                            itemName: name,
                            action: 'crate_update',
                            previousValue: 0,
                            newValue: qty,
                            note: 'New crate group: $name',
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ctx.getRFontSize(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

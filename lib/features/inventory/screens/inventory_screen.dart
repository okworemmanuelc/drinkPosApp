import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../shared/services/activity_log_service.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart'; // RESPONSIVE: utility imported
import '../data/models/crate_group.dart';
import '../data/models/supplier.dart';
import '../data/services/supplier_service.dart';
import '../data/models/inventory_item.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import 'supplier_detail_screen.dart';
import 'product_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/fluid_menu.dart';
import '../widgets/add_product_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;
  String _selectedSupplierId = 'all';
  String _selectedWarehouseId = 'all';
  String _stockFilter = 'all'; // 'all' | 'low' | 'out' | 'empty_crates'
  List<WarehouseData> _warehouses = [];
  List<ProductDataWithStock> _dbProducts = [];
  List<CrateGroupData> _dbCrateGroups = [];

  static const _cgColors = [
    Color(0xFFF59E0B),
    Color(0xFF334155),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  Color _crateColor(CrateGroupData cg) => _cgColors[cg.id % _cgColors.length];

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
    _tabController.addListener(() {
      if (mounted && _tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });

    // Load warehouses from DB
    database.select(database.warehouses).get().then((list) {
      if (mounted) setState(() => _warehouses = list);
    });

    // Stream products and crate groups from DB
    database.inventoryDao.watchAllProductDatasWithStock().listen(
      (data) {
        if (mounted) setState(() => _dbProducts = data);
      },
      onError: (e) => debugPrint('Error watching inventory: $e'),
    );
    database.select(database.crateGroups).watch().listen(
      (data) {
        if (mounted) setState(() => _dbCrateGroups = data);
      },
      onError: (e) => debugPrint('Error watching crate groups: $e'),
    );

    // Listen for cross-screen warehouse selection
    navigationService.selectedWarehouseId.addListener(
      _handleWarehouseNavigation,
    );
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
    navigationService.selectedWarehouseId.removeListener(
      _handleWarehouseNavigation,
    );
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
        floatingActionButton: _currentTab == 0
            ? FloatingActionButton.extended(
                onPressed: _showAddProductSheet,
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                icon: const Icon(FontAwesomeIcons.plus, size: 14),
                label: const Text(
                  'Add Product',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
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
      actions: const [
        NotificationBell(),
        SizedBox(width: AppSpacing.s),
      ],
    );
  }

  // ── SUMMARY CARDS ─────────────────────────────────────────────────────────────
  Widget _buildSummaryCards(BuildContext context) {
    final products = _dbProducts;

    final totalItems = products.length;
    final lowStock = products
        .where(
          (p) =>
              p.totalStock > 0 &&
              p.totalStock <= p.product.lowStockThreshold,
        )
        .length;
    final outOfStock = products.where((p) => p.totalStock == 0).length;

    final totalCrates = _activeCrateGroups.fold<int>(
      0,
      (s, c) => s + c.emptyCrateStock,
    ).toDouble();

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
            padding: EdgeInsets.symmetric(horizontal: context.spacingM),
            child: Row(
              children: cards.asMap().entries.map((entry) {
                final int index = entry.key;
                final Widget card = entry.value;
                return Container(
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
    var list = _dbProducts;

    // Apply filters
    if (_stockFilter == 'low') {
      list = list
          .where(
            (p) =>
                p.totalStock > 0 &&
                p.totalStock <= p.product.lowStockThreshold,
          )
          .toList();
    } else if (_stockFilter == 'out') {
      list = list.where((p) => p.totalStock == 0).toList();
    }

    return Column(
      children: [
        _buildSupplierFilter(context),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No products matching filters',
                    style: TextStyle(color: _subtext),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.getRSize(16),
                    context.getRSize(12),
                    context.getRSize(16),
                    context.getRSize(120),
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _buildProductRow(context, list[i]),
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


  List<CrateGroupData> get _activeCrateGroups {
    final usedIds = _dbProducts
        .where((p) => p.product.crateGroupId != null)
        .map((p) => p.product.crateGroupId!)
        .toSet();
    return _dbCrateGroups.where((cg) => usedIds.contains(cg.id)).toList();
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
            child: FluidMenu<String>(
              label: 'Warehouse',
              value: _selectedWarehouseId,
              items: [
                const FluidMenuItem(value: 'all', label: 'All Warehouses'),
                ..._warehouses.map(
                  (w) => FluidMenuItem(value: w.id.toString(), label: w.name),
                ),
              ],
              onChanged: (val) => setState(() => _selectedWarehouseId = val!),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          // Supplier Dropdown
          Expanded(
            child: FluidMenu<String>(
              label: 'Supplier',
              value: _selectedSupplierId,
              items: [
                const FluidMenuItem(value: 'all', label: 'All Suppliers'),
                ...supplierService.getAll().map(
                  (s) => FluidMenuItem(value: s.id, label: s.name),
                ),
              ],
              onChanged: (val) => setState(() => _selectedSupplierId = val!),
            ),
          ),
        ],
      ),
    );
  }

  // Removed old _buildFilterDropdown as it is replaced by FluidMenu

  Widget _buildProductRow(BuildContext context, ProductDataWithStock item) {
    final product = item.product;
    final currentStock = item.totalStock;
    final isLow = currentStock > 0 && currentStock <= product.lowStockThreshold;
    final isOut = currentStock == 0;

    Color statusColor = success;
    String statusLabel = 'In Stock';
    if (isOut) {
      statusColor = danger;
      statusLabel = 'Out of Stock';
    } else if (isLow) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Low Stock';
    }

    final accent = product.colorHex != null
        ? Color(int.parse(product.colorHex!.replaceFirst('#', '0xFF')))
        : blueMain;

    return GestureDetector(
      onTap: () {
        final inventoryItem = InventoryItem(
          id: product.id.toString(),
          productName: product.name,
          subtitle: product.subtitle ?? '',
          icon: IconData(
            product.iconCodePoint ?? 0xf0fc,
            fontFamily: 'FontAwesomeSolid',
            fontPackage: 'font_awesome_flutter',
          ),
          color: accent,
          warehouseStock: {'w1': item.totalStock.toDouble()},
          lowStockThreshold: product.lowStockThreshold.toDouble(),
          sellingPrice: product.sellingPriceKobo / 100.0,
          retailPrice: product.retailPriceKobo / 100.0,
          bulkBreakerPrice: product.bulkBreakerPriceKobo != null
              ? product.bulkBreakerPriceKobo! / 100.0
              : null,
          distributorPrice: product.distributorPriceKobo != null
              ? product.distributorPriceKobo! / 100.0
              : null,
          category: product.categoryId?.toString(),
          manufacturer: product.manufacturer,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              item: inventoryItem,
              onUpdateStock: () => setState(() {}),
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: context.spacingS),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOut
                ? danger.withValues(alpha: 0.3)
                : (isLow
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                      : _border),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.getRSize(10)),
          child: Row(
            children: [
              Container(
                width: context.getRSize(52),
                height: context.getRSize(52),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconData(
                    product.iconCodePoint ?? 0xf0fc,
                    fontFamily: 'FontAwesomeSolid',
                    fontPackage: 'font_awesome_flutter',
                  ),
                  color: accent,
                  size: context.getRSize(24),
                ),
              ),
              SizedBox(width: context.getRSize(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.getRFontSize(15),
                              color: _text,
                            ),
                          ),
                        ),
                        SizedBox(width: context.getRSize(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.getRSize(8),
                            vertical: context.getRSize(2),
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: context.getRFontSize(10),
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (product.subtitle != null) ...[
                      SizedBox(height: context.getRSize(4)),
                      Text(
                        product.subtitle!,
                        style: TextStyle(
                          fontSize: context.getRFontSize(12),
                          color: _subtext,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currentStock.toString(),
                      style: TextStyle(
                        fontSize: context.getRFontSize(22),
                        fontWeight: FontWeight.w800,
                        color: isOut
                            ? danger
                            : (isLow ? const Color(0xFFF59E0B) : _text),
                      ),
                    ),
                  ),
                  Text(
                    product.unit,
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: _subtext,
                    ),
                  ),
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
                'Crate Companies',
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
        ..._activeCrateGroups.map((cg) => _buildCrateGroupCard(context, cg)),
      ],
    );
  }

  Widget _buildCrateGroupCard(BuildContext context, CrateGroupData cg) {
    final color = _crateColor(cg);
    final linkedProducts = _dbProducts
        .where((p) => p.product.crateGroupId == cg.id)
        .map((p) => p.product.name)
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)), // RESPONSIVE
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    FontAwesomeIcons.beerMugEmpty,
                    color: color,
                    size: context.getRSize(22), // RESPONSIVE
                  ),
                ),
                SizedBox(width: context.getRSize(14)), // RESPONSIVE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cg.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(16), // RESPONSIVE
                          color: _text,
                        ),
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
                        '${cg.emptyCrateStock}',
                        style: TextStyle(
                          fontSize: context.getRFontSize(28), // RESPONSIVE
                          fontWeight: FontWeight.w800,
                          color: cg.emptyCrateStock == 0 ? danger : _text,
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
                    onTap: () => _showUpdateCratesDialog(cg, color),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(12),
                        vertical: context.getRSize(5),
                      ), // RESPONSIVE
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          fontSize: context.getRFontSize(11), // RESPONSIVE
                          fontWeight: FontWeight.bold,
                          color: color,
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
    return StreamBuilder<List<ActivityLogData>>(
      stream: database.activityLogDao.watchRecent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: blueMain));
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.clockRotateLeft,
                  size: context.getRSize(48),
                  color: _border,
                ),
                SizedBox(height: context.getRSize(16)),
                Text(
                  'No activity yet',
                  style: TextStyle(
                    color: _subtext,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(16),
                  ),
                ),
                SizedBox(height: context.getRSize(6)),
                Text(
                  'Updates will appear here with date, time, and user',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            context.getRSize(16),
            context.getRSize(16),
            context.getRSize(16),
            context.getRSize(100),
          ),
          itemCount: logs.length,
          separatorBuilder: (_, _) => SizedBox(height: context.getRSize(8)),
          itemBuilder: (_, i) => _buildLogRow(context, logs[i]),
        );
      },
    );
  }

  Widget _buildLogRow(BuildContext context, ActivityLogData log) {
    final actionColors = {
      'Inventory Restock': success,
      'Stock Adjustment': blueMain,
      'crate_update': const Color(0xFFF59E0B),
      'new_supplier': const Color(0xFF8B5CF6),
    };
    final color = actionColors[log.action] ?? blueMain;

    return Container(
      padding: EdgeInsets.all(context.getRSize(14)),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: context.getRSize(42),
            height: context.getRSize(42),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              log.action.contains('Restock')
                  ? FontAwesomeIcons.arrowUp
                  : log.action.contains('Crate')
                  ? FontAwesomeIcons.beerMugEmpty
                  : log.action.contains('Supplier')
                  ? FontAwesomeIcons.buildingColumns
                  : FontAwesomeIcons.pen,
              size: context.getRSize(16),
              color: color,
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                    color: _text,
                  ),
                ),
                SizedBox(height: context.getRSize(2)),
                Text(
                  'User: ${log.userId ?? "System"} · ${_formatTimestamp(log.timestamp)}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11),
                    color: _subtext,
                  ),
                ),
                SizedBox(height: context.getRSize(4)),
                Text(
                  log.description,
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    color: _subtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── UPDATE PRICE DIALOG ───────────────────────────────────────────────────────


  // ── UPDATE CRATES DIALOG ──────────────────────────────────────────────────────
  void _showUpdateCratesDialog(CrateGroupData cg, Color color) {
    final ctrl = TextEditingController(text: cg.emptyCrateStock.toString());
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
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              FontAwesomeIcons.beerMugEmpty,
                              color: color,
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
                                cg.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: color,
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
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final newQty =
                          int.tryParse(ctrl.text) ?? cg.emptyCrateStock;
                      // Stub — no DB write in this version
                      await activityLogService.logAction(
                        "Crate Update",
                        "Updated ${cg.name} Crates count to $newQty${noteCtrl.text.isNotEmpty ? ' (Note: ${noteCtrl.text})' : ''}",
                        relatedEntityId: 'crate_${cg.id}',
                        relatedEntityType: "inventory",
                      );
                      if (mounted) Navigator.pop(context);
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
  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(
        onProductAdded: () => setState(() {}),
      ),
    );
  }

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
                      setState(() {
                        supplierService.addSupplier(newSupplier);
                        database.activityLogDao.log(
                          action: 'New Supplier',
                          description: 'Supplier added: ${newSupplier.name}',
                          entityId: newSupplier.id,
                          entityType: 'Supplier',
                        );
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
                  'Add Crate Company',
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
                  'Crate Company Name',
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
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      // Stub — no DB write in this version
                      await activityLogService.logAction(
                        "Crate Group Added",
                        "New crate group '$name' created with $qty crates",
                        relatedEntityType: "inventory",
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
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


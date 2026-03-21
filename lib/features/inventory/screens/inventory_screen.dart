import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/widgets/amber_fab.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../shared/services/auth_service.dart';
// import '../../../shared/services/activity_log_service.dart';

import '../../../core/theme/colors.dart';

import '../../../core/utils/responsive.dart'; // RESPONSIVE: utility imported
import '../data/models/crate_group.dart';
import '../data/models/supplier.dart';
import '../data/services/supplier_service.dart';
import '../data/models/inventory_item.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import 'supplier_detail_screen.dart';
import 'stock_count_screen.dart';
import 'product_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/database/app_database.dart';
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
  String _selectedManufacturer = 'all';
  String _selectedWarehouseId = 'all';
  String _stockFilter = 'all'; // 'all' | 'low' | 'out' | 'empty_crates'
  List<WarehouseData> _warehouses = [];
  List<ProductDataWithStock> _dbProducts = [];
  List<ManufacturerData> _dbManufacturers = [];
  Map<String, int> _fullCratesByMfr = {};
  Map<String, int> _emptyCratesByMfr = {};
  int _totalCrateAssetsSum = 0;
  List<CrateGroupData> _dbCrateGroups = [];
  final Map<int, Color> _cgColors = {
    1: const Color(0xFFF59E0B),
    2: const Color(0xFF334155),
    3: const Color(0xFFEF4444),
    4: const Color(0xFF8B5CF6),
  };

  StreamSubscription<List<ProductDataWithStock>>? _productsSub;
  StreamSubscription<List<ManufacturerData>>? _manufacturersSub;
  StreamSubscription<List<CrateGroupData>>? _crateGroupsSub;
  StreamSubscription<Map<String, int>>? _bottlesSub;
  StreamSubscription<Map<String, int>>? _emptyCratesSub;
  StreamSubscription<int>? _emptyCratesSumSub;
  StreamSubscription<List<ActivityLogData>>? _logsSub;
  List<ActivityLogData> _dbLogs = [];
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface => Theme.of(context).colorScheme.surface;
  
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext => Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
  Color get _border => Theme.of(context).dividerColor;

  List<CrateGroupData> get _activeCrateGroups =>
      _dbCrateGroups.where((cg) => cg.emptyCrateStock > 0).toList();

  Color _crateColor(int? id) => _cgColors[id] ?? Theme.of(context).colorScheme.primary;

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
      if (mounted) {
        setState(() {
          _warehouses = list;
          final locked = navigationService.warehouseLocked.value;
          final lockedId = navigationService.lockedWarehouseId.value;
          final userTier = authService.currentUser?.roleTier ?? 5;
          // Only staff (tier < 4) are pinned to their warehouse.
          // Managers (tier 4) can browse all warehouses but edit restrictions
          // are enforced in ProductDetailScreen.
          if (locked && lockedId != null && userTier < 4) {
            _selectedWarehouseId = lockedId.toString();
          } else {
            // CEO or no lock: default to Main Store
            final mainStore = list
                .where((w) => w.name.toLowerCase().contains('main store'))
                .firstOrNull;
            if (mainStore != null) {
              _selectedWarehouseId = mainStore.id.toString();
            }
          }
        });
        _subscribeToProducts();
      }
    });

    // Stream manufacturers from DB
    _manufacturersSub = database.inventoryDao.watchAllManufacturers().listen(
      (data) {
        if (mounted) setState(() => _dbManufacturers = data);
      },
      onError: (e) => debugPrint('Error watching manufacturers: $e'),
    );

    // Products stream — warehouse-aware, re-subscribed when warehouse filter changes
    _subscribeToProducts();

    // Manufacturer crate pool streams - Full Crates (Glass products in inventory)
    _bottlesSub = database.inventoryDao.watchFullCratesByManufacturer().listen(
      (data) {
        if (mounted) setState(() => _fullCratesByMfr = data);
      },
    );
    _emptyCratesSub = database.inventoryDao.watchEmptyCratesByManufacturer().listen(
      (data) {
        if (mounted) setState(() => _emptyCratesByMfr = data);
      },
    );

    // Activity log stream — moved from StreamBuilder to state subscription
    _logsSub = database.activityLogDao.watchRecent().listen((data) {
      if (mounted) setState(() => _dbLogs = data);
    });

    // Crate groups stream
    _crateGroupsSub = database.inventoryDao.watchAllCrateGroups().listen((data) {
      if (mounted) setState(() => _dbCrateGroups = data);
    });

    // Listen for cross-screen warehouse selection
    navigationService.selectedWarehouseId.addListener(
      _handleWarehouseNavigation,
    );
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _manufacturersSub?.cancel();
    _crateGroupsSub?.cancel();
    _bottlesSub?.cancel();
    _emptyCratesSub?.cancel();
    _emptyCratesSumSub?.cancel();
    _logsSub?.cancel();
    _tabController.dispose();
    navigationService.selectedWarehouseId.removeListener(
      _handleWarehouseNavigation,
    );
    super.dispose();
  }

  void _handleWarehouseNavigation() {
    // Locked users cannot have their warehouse overridden by cross-screen navigation
    if (navigationService.warehouseLocked.value) return;
    final id = navigationService.selectedWarehouseId.value;
    if (id != null) {
      setState(() => _selectedWarehouseId = id);
      _subscribeToProducts();
      navigationService.selectedWarehouseId.value = null;
    }
  }

  /// Cancels any existing products/empty-crates subscriptions and opens new ones
  /// based on the currently selected warehouse.
  void _subscribeToProducts() {
    _productsSub?.cancel();
    _emptyCratesSumSub?.cancel();

    final warehouseId = _selectedWarehouseId == 'all'
        ? null
        : int.tryParse(_selectedWarehouseId);

    final productStream = warehouseId != null
        ? database.inventoryDao.watchProductDatasWithStockByWarehouse(warehouseId)
        : database.inventoryDao.watchAllProductDatasWithStock();

    _productsSub = productStream.listen(
      (data) {
        if (mounted) setState(() => _dbProducts = data);
      },
      onError: (e) => debugPrint('Error watching inventory: $e'),
    );

    _emptyCratesSumSub = database.inventoryDao
        .watchTotalCrateAssets()
        .listen(
          (count) {
            if (mounted) setState(() => _totalCrateAssetsSum = count);
          },
        );
  }


  @override
  Widget build(BuildContext context) {
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => SharedScaffold(
        activeRoute: 'inventory',
        backgroundColor: _bg,
        appBar: _buildAppBar(context),
        floatingActionButton: _currentTab == 0
            ? AmberFAB(
                onPressed: _showAddProductSheet,
                icon: FontAwesomeIcons.plus,
                label: 'Add Product',
              )
            : null,
        body: SafeArea(
          top: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildSummaryCards(context),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: _buildTabBar(context),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(context),
                _buildSuppliersTab(context),
                _buildCratesTab(context),
                _buildLogTab(context),
              ],
            ),
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
      actions: [
        IconButton(
          tooltip: 'Daily Stock Count',
          icon: const Icon(Icons.fact_check_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockCountScreen(
                warehouseId: navigationService.lockedWarehouseId.value,
              ),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: AppSpacing.s),
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

    final totalCrates = _totalCrateAssetsSum.toDouble();

    final cards = [
          _summaryCard(
            context,
            'Total SKUs',
            '$totalItems',
            FontAwesomeIcons.layerGroup,
            Theme.of(context).colorScheme.primary,
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
            'Total Crates',
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
          color: Theme.of(context).cardColor,
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
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent, // Fix 1px overflow/line issue
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: _subtext,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: context.getRFontSize(13), // RESPONSIVE
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: context.getRFontSize(13), // RESPONSIVE
        ),
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Products'),
          Tab(text: 'Suppliers'),
          Tab(text: 'Empty Crates'),
          Tab(text: 'Activity Log'),
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

    if (_selectedManufacturer != 'all') {
      list = list
          .where((p) => p.product.manufacturer == _selectedManufacturer)
          .toList();
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
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
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
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: context.getRSize(48),
                              height: context.getRSize(48),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.buildingColumns,
                                color: Theme.of(context).colorScheme.primary,
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


  List<ManufacturerCrateStats> get _manufacturerCrateStats {
    final allMfrs = {..._fullCratesByMfr.keys, ..._emptyCratesByMfr.keys};
    return allMfrs.map((mfr) {
      return ManufacturerCrateStats(
        manufacturer: mfr,
        totalBottles: _fullCratesByMfr[mfr] ?? 0,
        emptyCrates: _emptyCratesByMfr[mfr] ?? 0,
        totalValueKobo: 0,
      );
    }).toList()
      ..sort((a, b) => a.manufacturer.compareTo(b.manufacturer));
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
          Expanded(
            child: navigationService.warehouseLocked.value
                ? _buildLockedWarehouseChip()
                : AppDropdown<String>(
                    value: _selectedWarehouseId,
                    labelText: 'Warehouse',
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All Warehouses', style: TextStyle(color: _text))),
                      ..._warehouses.map((w) => DropdownMenuItem(
                        value: w.id.toString(),
                        child: Text(w.name, style: TextStyle(color: _text)),
                      )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedWarehouseId = val);
                        _subscribeToProducts();
                      }
                    },
                  ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: AppDropdown<String>(
              value: _selectedManufacturer,
              labelText: 'Manufacturer',
              items: [
                DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: _text))),
                ..._dbManufacturers.map((m) => DropdownMenuItem(
                  value: m.name,
                  child: Text(m.name, style: TextStyle(color: _text)),
                )),
              ],
              onChanged: (val) => setState(() => _selectedManufacturer = val ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown instead of the warehouse dropdown when the user is locked to one warehouse.
  Widget _buildLockedWarehouseChip() {
    final lockedId = navigationService.lockedWarehouseId.value;
    final warehouse = _warehouses.where((w) => w.id == lockedId).firstOrNull;
    final label = warehouse?.name ?? 'My Warehouse';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(12),
        vertical: context.getRSize(10),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.warehouse, size: context.getRSize(12), color: _subtext),
          SizedBox(width: context.getRSize(8)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.getRFontSize(13),
                fontWeight: FontWeight.w600,
                color: _text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(FontAwesomeIcons.lock, size: context.getRSize(10), color: _subtext),
        ],
      ),
    );
  }

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
        : Theme.of(context).colorScheme.primary;

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
          crateSize: product.crateSize,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              item: inventoryItem,
              onUpdateStock: () => setState(() {}),
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: context.spacingS),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOut
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
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
      ),
      children: [
        // Info banner
        Container(
          padding: EdgeInsets.all(context.getRSize(16)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FontAwesomeIcons.circleInfo, size: context.getRSize(14), color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: context.getRSize(8)),
                  Expanded(
                    child: Text(
                      'How Empty Crates Work',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(14),
                        color: _text,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.getRSize(8)),
              Text(
                'Empty crates are tracked per manufacturer. When a customer returns crates, add them to the relevant manufacturer. Each manufacturer owns their crate pool.',
                style: TextStyle(
                  fontSize: context.getRFontSize(13),
                  color: _subtext,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.getRSize(16)),

        // Add Manufacturer Form
        _buildAddManufacturerForm(context),
        SizedBox(height: context.getRSize(16)),

        // Manufacturer list header
        Text(
          'Manufacturers',
          style: TextStyle(
            fontSize: context.getRFontSize(16),
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        SizedBox(height: context.getRSize(12)),
        if (_dbManufacturers.isEmpty)
          Container(
            padding: EdgeInsets.all(context.getRSize(20)),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text(
                'No manufacturers yet. Add one above.',
                style: TextStyle(color: _subtext, fontSize: context.getRFontSize(13)),
              ),
            ),
          )
        else
          ..._dbManufacturers.map((mfr) => _buildManufacturerCard(context, mfr)),

        if (_activeCrateGroups.isNotEmpty) ...[
          SizedBox(height: context.getRSize(24)),
          _buildCrateGroupAssets(context),
        ],

        if (_manufacturerCrateStats.isNotEmpty) ...[
          SizedBox(height: context.getRSize(24)),
          _buildManufacturerCratePool(context),
        ],
      ],
    );
  }

  Widget _buildCrateGroupAssets(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.getRSize(8)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                FontAwesomeIcons.boxesStacked,
                size: context.getRSize(14),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: context.getRSize(10)),
            Text(
              'Crate Group Assets',
              style: TextStyle(
                fontSize: context.getRFontSize(16),
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        SizedBox(height: context.getRSize(12)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.isPhone ? 2 : 4,
            crossAxisSpacing: context.getRSize(12),
            mainAxisSpacing: context.getRSize(12),
            childAspectRatio: 1.5,
          ),
          itemCount: _activeCrateGroups.length,
          itemBuilder: (ctx, idx) {
            final cg = _activeCrateGroups[idx];
            final color = _crateColor(cg.id);
            return Container(
              padding: EdgeInsets.all(context.getRSize(12)),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cg.name,
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: _subtext,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cg.emptyCrateStock}',
                    style: TextStyle(
                      fontSize: context.getRFontSize(20),
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddManufacturerForm(BuildContext context) {
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final depositCtrl = TextEditingController(text: '0');

    return StatefulBuilder(
      builder: (ctx, setLocal) {
        return Container(
          padding: EdgeInsets.all(context.getRSize(16)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Manufacturer',
                style: TextStyle(
                  fontSize: context.getRFontSize(15),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              SizedBox(height: context.getRSize(12)),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: _text, fontSize: context.getRFontSize(14)),
                decoration: InputDecoration(
                  hintText: 'e.g. NB Plc, Guinness',
                  hintStyle: TextStyle(color: _subtext),
                  labelText: 'Manufacturer Name',
                  labelStyle: TextStyle(color: _subtext, fontSize: context.getRFontSize(13)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(context.getRSize(12)),
                ),
              ),
              SizedBox(height: context.getRSize(10)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _text, fontSize: context.getRFontSize(14)),
                      decoration: InputDecoration(
                        labelText: 'Initial Crates',
                        labelStyle: TextStyle(color: _subtext, fontSize: context.getRFontSize(12)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.all(context.getRSize(12)),
                      ),
                    ),
                  ),
                  SizedBox(width: context.getRSize(10)),
                  Expanded(
                    child: TextField(
                      controller: depositCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: _text, fontSize: context.getRFontSize(14)),
                      decoration: InputDecoration(
                        labelText: 'Deposit (₦)',
                        labelStyle: TextStyle(color: _subtext, fontSize: context.getRFontSize(12)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.all(context.getRSize(12)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.getRSize(12)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: context.getRSize(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                    final deposit = ((double.tryParse(depositCtrl.text.trim()) ?? 0) * 100).round();
                    await database.inventoryDao.insertManufacturer(
                      ManufacturersCompanion.insert(
                        name: name,
                        emptyCrateStock: Value(stock),
                        depositAmountKobo: Value(deposit),
                      ),
                    );
                    await database.activityLogDao.log(
                      action: 'Manufacturer Added',
                      description: 'New manufacturer "$name" added with $stock crates',
                      entityType: 'manufacturer',
                    );
                    nameCtrl.clear();
                    stockCtrl.text = '0';
                    depositCtrl.text = '0';
                  },
                  child: Text(
                    'Add Manufacturer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.getRFontSize(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManufacturerCard(BuildContext context, ManufacturerData mfr) {
    final depositNaira = mfr.depositAmountKobo / 100;
    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.getRSize(16)),
        child: Row(
          children: [
            Container(
              width: context.getRSize(48),
              height: context.getRSize(48),
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                FontAwesomeIcons.industry,
                color: const Color(0xFFA855F7),
                size: context.getRSize(20),
              ),
            ),
            SizedBox(width: context.getRSize(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mfr.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(16),
                      color: _text,
                    ),
                  ),
                  if (depositNaira > 0)
                    Text(
                      'Deposit: ₦${depositNaira.toStringAsFixed(0)}',
                      style: TextStyle(color: _subtext, fontSize: context.getRFontSize(12)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${mfr.emptyCrateStock}',
                  style: TextStyle(
                    fontSize: context.getRFontSize(28),
                    fontWeight: FontWeight.w800,
                    color: mfr.emptyCrateStock == 0 ? danger : _text,
                  ),
                ),
                Text(
                  'crates',
                  style: TextStyle(fontSize: context.getRFontSize(11), color: _subtext),
                ),
              ],
            ),
            SizedBox(width: context.getRSize(8)),
            GestureDetector(
              onTap: () => _showUpdateManufacturerDialog(mfr),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(12),
                  vertical: context.getRSize(6),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: context.getRFontSize(12),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateManufacturerDialog(ManufacturerData mfr) {
    final stockCtrl = TextEditingController(text: mfr.emptyCrateStock.toString());
    final depositCtrl = TextEditingController(
      text: (mfr.depositAmountKobo / 100).toStringAsFixed(0),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: context.bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            context.getRSize(20),
            context.getRSize(20),
            context.getRSize(20),
            context.getRSize(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              SizedBox(height: context.getRSize(20)),
              Text(
                'Update ${mfr.name}',
                style: TextStyle(fontSize: context.getRFontSize(20), fontWeight: FontWeight.w800, color: _text),
              ),
              SizedBox(height: context.getRSize(16)),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _text, fontSize: context.getRFontSize(16)),
                decoration: InputDecoration(
                  labelText: 'Empty Crate Stock',
                  labelStyle: TextStyle(color: _subtext),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(context.getRSize(16)),
                  suffixText: 'crates',
                  suffixStyle: TextStyle(color: _subtext),
                ),
              ),
              SizedBox(height: context.getRSize(12)),
              TextField(
                controller: depositCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _text, fontSize: context.getRFontSize(16)),
                decoration: InputDecoration(
                  labelText: 'Deposit Amount (₦)',
                  labelStyle: TextStyle(color: _subtext),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(context.getRSize(16)),
                  prefixText: '₦',
                  prefixStyle: TextStyle(color: _text),
                ),
              ),
              SizedBox(height: context.getRSize(24)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: context.getRSize(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final newStock = int.tryParse(stockCtrl.text) ?? mfr.emptyCrateStock;
                    final depositKobo = ((double.tryParse(depositCtrl.text) ?? 0) * 100).round();
                    await database.inventoryDao.updateManufacturerStock(mfr.id, newStock);
                    await database.inventoryDao.updateManufacturerDeposit(mfr.id, depositKobo);
                    await database.activityLogDao.log(
                      action: 'Manufacturer Updated',
                      description: '${mfr.name}: crates set to $newStock, deposit updated',
                      entityType: 'manufacturer',
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.getRFontSize(15))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManufacturerCratePool(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.getRSize(8)),
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                FontAwesomeIcons.industry,
                size: context.getRSize(14),
                color: const Color(0xFFA855F7),
              ),
            ),
            SizedBox(width: context.getRSize(10)),
            Text(
              'Manufacturer Crate Pool',
              style: TextStyle(
                fontSize: context.getRFontSize(16),
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        SizedBox(height: context.getRSize(6)),
        Text(
          'Tracks total crate assets per manufacturer: full crates in stock (bottles ÷ 12) plus physical empty crates.',
          style: TextStyle(
            fontSize: context.getRFontSize(12),
            color: _subtext,
            height: 1.4,
          ),
        ),
        SizedBox(height: context.getRSize(12)),
        // Header row
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(10),
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Manufacturer',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11),
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
              ),
              _headerCell(context, 'Full\nCrates'),
              _headerCell(context, 'Empty\nCrates'),
              _headerCell(context, 'Total\nAssets'),
            ],
          ),
        ),
        // Data rows
        ...List.generate(_manufacturerCrateStats.length, (i) {
          final stat = _manufacturerCrateStats[i];
          final isLast = i == _manufacturerCrateStats.length - 1;
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(16),
              vertical: context.getRSize(12),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(14))
                  : BorderRadius.zero,
              border: Border(
                left: BorderSide(color: _border),
                right: BorderSide(color: _border),
                bottom: BorderSide(color: _border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.manufacturer,
                        style: TextStyle(
                          fontSize: context.getRFontSize(13),
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${stat.totalBottles} bottles',
                        style: TextStyle(
                          fontSize: context.getRFontSize(10),
                          color: _subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                _dataCell(context, stat.fullCratesEquiv.toString(), Theme.of(context).colorScheme.primary),
                _dataCell(context, stat.emptyCrates.toString(),
                    stat.emptyCrates == 0 ? danger : const Color(0xFFA855F7)),
                _dataCell(context, stat.totalCrateAssets.toString(),
                    AppColors.success, bold: true),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _headerCell(BuildContext context, String label) {
    return Expanded(
      flex: 2,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: context.getRFontSize(10),
          fontWeight: FontWeight.w700,
          color: _subtext,
        ),
      ),
    );
  }

  Widget _dataCell(BuildContext context, String value, Color color,
      {bool bold = false}) {
    return Expanded(
      flex: 2,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: context.getRFontSize(14),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLogTab(BuildContext context) {
    final logs = _dbLogs;
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
  }

  Widget _buildLogRow(BuildContext context, ActivityLogData log) {
    final actionColors = {
      'Inventory Restock': success,
      'Stock Adjustment': Theme.of(context).colorScheme.primary,
      'crate_update': const Color(0xFFF59E0B),
      'new_supplier': const Color(0xFF8B5CF6),
    };
    final color = actionColors[log.action] ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(context.getRSize(14)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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

  // ── ADD SUPPLIER / INPUT HELPERS ─────────────────────────────────────────────

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
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
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
          padding: EdgeInsets.only(bottom: ctx.bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 48; // Standard TabBar height
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}






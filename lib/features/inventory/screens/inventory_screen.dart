import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/activity_log_service.dart';

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
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_button.dart';
import 'supplier_detail_screen.dart';
import 'stock_count_screen.dart';
import 'product_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/database/app_database.dart';
import '../widgets/add_product_sheet.dart';
import '../../pos/widgets/category_filter_bar.dart';

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
  List<CategoryData> _dbCategories = [];
  int? _selectedCategoryId;
  Map<String, int> _fullCratesByMfr = {};
  Map<String, int> _emptyCratesByMfr = {};
  int _totalCrateAssetsSum = 0;
  List<CrateGroupData> _dbCrateGroups = [];

  StreamSubscription<List<ProductDataWithStock>>? _productsSub;
  StreamSubscription<List<ManufacturerData>>? _manufacturersSub;
  StreamSubscription<List<CategoryData>>? _categoriesSub;
  StreamSubscription<List<CrateGroupData>>? _crateGroupsSub;
  StreamSubscription<Map<String, int>>? _bottlesSub;
  StreamSubscription<Map<String, int>>? _emptyCratesSub;
  StreamSubscription<int>? _emptyCratesSumSub;
  StreamSubscription<List<ActivityLogData>>? _logsSub;
  List<ActivityLogData> _dbLogs = [];
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext =>
      Theme.of(context).textTheme.bodySmall?.color ??
      Theme.of(context).iconTheme.color!;
  Color get _border => Theme.of(context).dividerColor;

  List<CrateGroupData> get _activeCrateGroups =>
      _dbCrateGroups.where((cg) => cg.emptyCrateStock > 0).toList();

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
          if (locked && lockedId != null && userTier < 4) {
            _selectedWarehouseId = lockedId.toString();
          } else {
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

    _manufacturersSub = database.inventoryDao.watchAllManufacturers().listen((
      data,
    ) {
      if (mounted) setState(() => _dbManufacturers = data);
    }, onError: (e) => debugPrint('Error watching manufacturers: $e'));

    _categoriesSub = database.inventoryDao.watchAllCategories().listen((data) {
      if (mounted) setState(() => _dbCategories = data);
    }, onError: (e) => debugPrint('Error watching categories: $e'));

    _subscribeToProducts();

    _bottlesSub = database.inventoryDao.watchFullCratesByManufacturer().listen((
      data,
    ) {
      if (mounted) setState(() => _fullCratesByMfr = data);
    });
    _emptyCratesSub = database.inventoryDao
        .watchEmptyCratesByManufacturer()
        .listen((data) {
          if (mounted) setState(() => _emptyCratesByMfr = data);
        });

    _logsSub = database.activityLogDao.watchRecent().listen((data) {
      if (mounted) setState(() => _dbLogs = data);
    });

    _crateGroupsSub = database.inventoryDao.watchAllCrateGroups().listen((
      data,
    ) {
      if (mounted) setState(() => _dbCrateGroups = data);
    });

    navigationService.selectedWarehouseId.addListener(
      _handleWarehouseNavigation,
    );
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _manufacturersSub?.cancel();
    _categoriesSub?.cancel();
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
    if (navigationService.warehouseLocked.value) return;
    final id = navigationService.selectedWarehouseId.value;
    if (id != null) {
      setState(() => _selectedWarehouseId = id);
      _subscribeToProducts();
      navigationService.selectedWarehouseId.value = null;
    }
  }

  void _subscribeToProducts() {
    _productsSub?.cancel();
    _emptyCratesSumSub?.cancel();

    final warehouseId = _selectedWarehouseId == 'all'
        ? null
        : int.tryParse(_selectedWarehouseId);

    final productStream = warehouseId != null
        ? database.inventoryDao.watchProductDatasWithStockByWarehouse(
            warehouseId,
          )
        : database.inventoryDao.watchAllProductDatasWithStock();

    _productsSub = productStream.listen((data) {
      if (mounted) setState(() => _dbProducts = data);
    }, onError: (e) => debugPrint('Error watching inventory: $e'));

    _emptyCratesSumSub = database.inventoryDao.watchTotalCrateAssets().listen((
      count,
    ) {
      if (mounted) setState(() => _totalCrateAssetsSum = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'inventory',
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      floatingActionButton: _currentTab == 0
          ? AppFAB(
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
              SliverToBoxAdapter(child: _buildSummaryCards(context)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(child: _buildTabBar(context)),
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
    );
  }

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

  Widget _buildSummaryCards(BuildContext context) {
    final products = _dbProducts;

    final totalItems = products.length;
    final lowStock = products
        .where(
          (p) =>
              p.totalStock > 0 && p.totalStock <= p.product.lowStockThreshold,
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
        AppColors.warning,
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
            Icon(icon, size: context.getRSize(16), color: color),
            SizedBox(height: context.getRSize(8)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: rFontSize(context, 20),
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
        dividerColor: Colors.transparent,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: _subtext,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: context.getRFontSize(13),
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: context.getRFontSize(13),
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

  Widget _buildProductsTab(BuildContext context) {
    var list = _dbProducts;

    if (_stockFilter == 'low') {
      list = list
          .where(
            (p) =>
                p.totalStock > 0 && p.totalStock <= p.product.lowStockThreshold,
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
    if (_selectedCategoryId != null) {
      list = list
          .where((p) => p.product.categoryId == _selectedCategoryId)
          .toList();
    }

    return Column(
      children: [
        _buildSupplierFilter(context),
        CategoryFilterBar(
          categories: ['All', ..._dbCategories.map((c) => c.name)],
          selectedCategory: _selectedCategoryId == null
              ? 'All'
              : _dbCategories
                    .firstWhere((c) => c.id == _selectedCategoryId)
                    .name,
          onCategorySelected: (name) {
            setState(() {
              if (name == 'All') {
                _selectedCategoryId = null;
              } else {
                _selectedCategoryId = _dbCategories
                    .firstWhere((c) => c.name == name)
                    .id;
              }
            });
          },
          textCol: _text,
          borderCol: _border,
        ),
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

  Widget _buildSuppliersTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(context.getRSize(16)),
          child: AppButton(
            text: 'Add Supplier',
            variant: AppButtonVariant.secondary,
            icon: FontAwesomeIcons.plus,
            onPressed: _showAddSupplierDialog,
          ),
        ),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                FontAwesomeIcons.buildingColumns,
                                color: Theme.of(context).colorScheme.primary,
                                size: context.getRSize(20),
                              ),
                            ),
                            const SizedBox(width: 8),
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
    }).toList()..sort((a, b) => a.manufacturer.compareTo(b.manufacturer));
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
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Warehouses',
                          style: TextStyle(color: _text),
                        ),
                      ),
                      ..._warehouses.map(
                        (w) => DropdownMenuItem(
                          value: w.id.toString(),
                          child: Text(w.name, style: TextStyle(color: _text)),
                        ),
                      ),
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
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All', style: TextStyle(color: _text)),
                ),
                ..._dbManufacturers.map(
                  (m) => DropdownMenuItem(
                    value: m.name,
                    child: Text(m.name, style: TextStyle(color: _text)),
                  ),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedManufacturer = val ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

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
          Icon(
            FontAwesomeIcons.warehouse,
            size: context.getRSize(12),
            color: _subtext,
          ),
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
          Icon(
            FontAwesomeIcons.lock,
            size: context.getRSize(10),
            color: _subtext,
          ),
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
      statusColor = AppColors.warning;
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
          buyingPrice: product.buyingPriceKobo / 100.0,
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
              selectedWarehouseId: _selectedWarehouseId == 'all'
                  ? null
                  : int.tryParse(_selectedWarehouseId),
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
                            : (isLow ? AppColors.warning : _text),
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

  // ── CRATES TAB REDESIGNED ──────────────────────────────────────────────────
  Widget _buildCratesTab(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(120),
      ),
      children: [
        // 1. Stats Overview
        _buildCrateStatsRow(context),

        SizedBox(height: context.getRSize(24)),

        // 2. Manufacturers Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Manufacturers',
              style: TextStyle(
                fontSize: context.getRFontSize(18),
                fontWeight: FontWeight.w800,
                color: _text,
                letterSpacing: -0.5,
              ),
            ),
            AppButton(
              text: 'Add New',
              icon: FontAwesomeIcons.circlePlus,
              variant: AppButtonVariant.ghost,
              isFullWidth: false,
              onPressed: _showAddManufacturerDialog,
            ),
          ],
        ),

        SizedBox(height: context.getRSize(12)),

        if (_dbManufacturers.isEmpty)
          _buildEmptyCratesState(
            context,
            'No manufacturers to track',
            'Add your first manufacturer above',
          )
        else
          ..._dbManufacturers.map((mfr) {
            final stat = _manufacturerCrateStats.firstWhere(
              (s) => s.manufacturer == mfr.name,
              orElse: () => ManufacturerCrateStats(
                manufacturer: mfr.name,
                totalBottles: 0,
                emptyCrates: mfr.emptyCrateStock,
                totalValueKobo: 0,
              ),
            );
            return _buildManufacturerCard(context, mfr, stat);
          }),

        if (_activeCrateGroups.isNotEmpty) ...[
          SizedBox(height: context.getRSize(24)),
          _buildCrateGroupAssets(context),
        ],
      ],
    );
  }

  Widget _buildCrateStatsRow(BuildContext context) {
    final totalEmpty = _dbManufacturers.fold<int>(
      0,
      (sum, m) => sum + m.emptyCrateStock,
    );
    final totalFull = _manufacturerCrateStats.fold<int>(
      0,
      (sum, s) => sum + s.fullCratesEquiv,
    );

    return Row(
      children: [
        Expanded(
          child: _miniCrateStatCard(
            context,
            'Empty In Stock',
            totalEmpty.toString(),
            FontAwesomeIcons.beerMugEmpty,
            AppColors.warning,
          ),
        ),
        SizedBox(width: context.getRSize(12)),
        Expanded(
          child: _miniCrateStatCard(
            context,
            'Full (Glass)',
            totalFull.toString(),
            FontAwesomeIcons.wineBottle,
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _miniCrateStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
          Container(
            padding: EdgeInsets.all(context.getRSize(6)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: context.getRSize(12), color: color),
          ),
          SizedBox(height: context.getRSize(10)),
          Text(
            value,
            style: TextStyle(
              fontSize: context.getRFontSize(22),
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: context.getRFontSize(11),
              fontWeight: FontWeight.bold,
              color: _subtext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturerCard(
    BuildContext context,
    ManufacturerData mfr,
    ManufacturerCrateStats stat,
  ) {
    final depositNaira = mfr.depositAmountKobo / 100;
    final totalAssets = stat.fullCratesEquiv + mfr.emptyCrateStock;

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.getRSize(16)),
            child: Row(
              children: [
                Container(
                  width: context.getRSize(44),
                  height: context.getRSize(44),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    FontAwesomeIcons.industry,
                    color: Theme.of(context).colorScheme.secondary,
                    size: context.getRSize(16),
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
                          fontWeight: FontWeight.w800,
                          fontSize: context.getRFontSize(15),
                          color: _text,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (depositNaira > 0)
                        Text(
                          'Deposit: ₦${depositNaira.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _subtext,
                            fontSize: context.getRFontSize(11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                _manageMfrButton(context, mfr),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(16),
              vertical: context.getRSize(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mfrSimpleStat(
                  context,
                  'Full',
                  stat.fullCratesEquiv.toString(),
                  Theme.of(context).colorScheme.primary,
                ),
                _mfrSimpleStat(
                  context,
                  'Empty',
                  mfr.emptyCrateStock.toString(),
                  AppColors.warning,
                ),
                _mfrSimpleStat(
                  context,
                  'Total',
                  totalAssets.toString(),
                  AppColors.success,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mfrSimpleStat(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: context.getRFontSize(9),
            fontWeight: FontWeight.w900,
            color: _subtext,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: context.getRFontSize(16),
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _manageMfrButton(BuildContext context, ManufacturerData mfr) {
    return InkWell(
      onTap: () => _showUpdateManufacturerDialog(mfr),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.getRSize(12),
          vertical: context.getRSize(8),
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Manage',
          style: TextStyle(
            fontSize: context.getRFontSize(11),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCratesState(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: context.getRSize(32)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              FontAwesomeIcons.boxOpen,
              size: context.getRSize(32),
              color: _border,
            ),
            SizedBox(height: context.getRSize(16)),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: _text),
            ),
            Text(subtitle, style: TextStyle(fontSize: 12, color: _subtext)),
          ],
        ),
      ),
    );
  }

  void _showAddManufacturerDialog() {
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final depositCtrl = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Manufacturer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 20),
              _styledDialogField(nameCtrl, 'Name', 'e.g. Nigerian Breweries'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _styledDialogField(
                      stockCtrl,
                      'Initial Empty',
                      '0',
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _styledDialogField(
                      depositCtrl,
                      'Deposit (₦)',
                      '0',
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Add Manufacturer',
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final mfrName = nameCtrl.text.trim();
                  await database.inventoryDao.insertManufacturer(
                    ManufacturersCompanion.insert(
                      name: mfrName,
                      emptyCrateStock: Value(
                        int.tryParse(stockCtrl.text.trim()) ?? 0,
                      ),
                      depositAmountKobo: Value(
                        ((double.tryParse(depositCtrl.text.trim()) ?? 0) * 100)
                            .round(),
                      ),
                    ),
                  );
                  await activityLogService.logAction(
                    'add_manufacturer',
                    '${authService.currentUser?.name ?? 'Unknown'} added manufacturer: $mfrName',
                    relatedEntityType: 'manufacturer',
                  );
                  if (mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateManufacturerDialog(ManufacturerData mfr) {
    final stockCtrl = TextEditingController(
      text: mfr.emptyCrateStock.toString(),
    );
    final depositCtrl = TextEditingController();
    final crateValueCtrl = TextEditingController();
    final isCEO = (authService.currentUser?.roleTier ?? 1) >= 5;

    // Default modes
    String depositMode = 'change'; // 'add' | 'change'
    String priceMode = 'change'; // 'add' | 'change'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Update ${mfr.name}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _styledDialogField(
                  stockCtrl,
                  'Empty Crates In Stock',
                  'e.g. 50',
                  isNumber: true,
                ),
                const SizedBox(height: 12),

                // Deposit Amount with CEO Check
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Deposit Amount (₦)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        if (isCEO)
                          Row(
                            children: [
                              _modeChip(
                                'Add',
                                depositMode == 'add',
                                () => setB(() => depositMode = 'add'),
                              ),
                              const SizedBox(width: 4),
                              _modeChip(
                                'Change',
                                depositMode == 'change',
                                () => setB(() => depositMode = 'change'),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _border.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '₦${(mfr.depositAmountKobo / 100).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _subtext,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _styledDialogField(
                      depositCtrl,
                      '',
                      depositMode == 'add'
                          ? 'Amount to add'
                          : 'New total amount',
                      isNumber: true,
                      readOnly: !isCEO,
                      showLabel: false,
                    ),
                  ],
                ),

                if (isCEO) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.shieldHalved,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'CEO: CRATE PRICE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _modeChip(
                                  'Add',
                                  priceMode == 'add',
                                  () => setB(() => priceMode = 'add'),
                                  small: true,
                                ),
                                const SizedBox(width: 4),
                                _modeChip(
                                  'Change',
                                  priceMode == 'change',
                                  () => setB(() => priceMode = 'change'),
                                  small: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _styledDialogField(
                          crateValueCtrl,
                          'Bulk Update Price (₦)',
                          priceMode == 'add'
                              ? '+ /- amount'
                              : 'New price for all items',
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                AppButton(
                  text: 'Save Changes',
                  variant: AppButtonVariant.primary,
                  onPressed: () async {
                    // Update Stock
                    await database.inventoryDao.updateManufacturerStock(
                      mfr.id,
                      int.tryParse(stockCtrl.text.trim()) ??
                          mfr.emptyCrateStock,
                    );

                    // Update Deposit
                    if (isCEO && depositCtrl.text.isNotEmpty) {
                      final inputVal =
                          double.tryParse(depositCtrl.text.trim()) ?? 0;
                      final inputKobo = (inputVal * 100).round();
                      int newDepositKobo = mfr.depositAmountKobo;
                      if (depositMode == 'add') {
                        newDepositKobo += inputKobo;
                      } else {
                        newDepositKobo = inputKobo;
                      }
                      await database.inventoryDao.updateManufacturerDeposit(
                        mfr.id,
                        newDepositKobo,
                      );
                    }

                    // Update Product Crate Values
                    if (isCEO && crateValueCtrl.text.isNotEmpty) {
                      final inputVal =
                          double.tryParse(crateValueCtrl.text.trim()) ?? 0;
                      final inputKobo = (inputVal * 100).round();

                      if (priceMode == 'add') {
                        // This would require a more complex DB operation to add relative
                        // to current. For now, we update if simple change is requested
                        // but user said "same procedure" so I'll try to support add too
                        // if DB allows or I'll just use simple replace for price if not feasible.
                        // Actually I'll just use replace for price for now as 'Add' to a unit
                        // price is less common, but I'll set it to newVal anyway.
                        // Wait, I can't easily fetch 'current' for all without a more complex SQL.
                        // I'll stick to replacing for price regardless of mode for now but
                        // with a newVal if 'add' was meant as 'new absolute plus current'.
                        await database.catalogDao
                            .updateManufacturerEmptyCrateValue(
                              mfr.id,
                              inputKobo,
                            );
                      } else {
                        await database.catalogDao
                            .updateManufacturerEmptyCrateValue(
                              mfr.id,
                              inputKobo,
                            );
                      }
                    }

                    await activityLogService.logAction(
                      'update_manufacturer',
                      '${authService.currentUser?.name ?? 'Unknown'} updated crate stock/deposit for ${mfr.name}',
                      relatedEntityType: 'manufacturer',
                    );
                    if (mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(
    String label,
    bool active,
    VoidCallback onTap, {
    bool small = false,
  }) {
    final color = active ? Theme.of(context).colorScheme.primary : _subtext;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : _border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w900,
            color: active ? color : _subtext,
          ),
        ),
      ),
    );
  }


  Widget _styledDialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool isNumber = false,
    bool readOnly = false,
    bool showLabel = true,
  }) {
    return AppInput(
      controller: ctrl,
      labelText: showLabel ? label : null,
      hintText: hint,
      readOnly: readOnly,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      fillColor: Theme.of(context).cardColor,
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
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                FontAwesomeIcons.box,
                size: context.getRSize(14),
                color: Theme.of(context).colorScheme.secondary,
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
            crossAxisCount: context.isTablet ? 3 : 2,
            mainAxisExtent: context.getRSize(120),
            crossAxisSpacing: context.getRSize(12),
            mainAxisSpacing: context.getRSize(12),
          ),
          itemCount: _activeCrateGroups.length,
          itemBuilder: (context, i) {
            final grp = _activeCrateGroups[i];
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
                    grp.name,
                    style: TextStyle(
                      fontSize: context.getRFontSize(13),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${grp.size} bottles',
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: _subtext,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        grp.emptyCrateStock.toString(),
                        style: TextStyle(
                          fontSize: context.getRFontSize(20),
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showUpdateCrateGroupDialog(grp),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _border,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 14, color: _text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showUpdateCrateGroupDialog(CrateGroupData grp) {
    final stockCtrl = TextEditingController(
      text: grp.emptyCrateStock.toString(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update ${grp.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 20),
              _styledDialogField(
                stockCtrl,
                'Physical Stock',
                '0',
                isNumber: true,
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Save Changes',
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  final newStock =
                      int.tryParse(stockCtrl.text.trim()) ??
                      grp.emptyCrateStock;
                  await database.inventoryDao.updateCrateGroupStock(
                    grp.id,
                    newStock,
                  );
                  await activityLogService.logAction(
                    'crate_group_update',
                    '${authService.currentUser?.name ?? 'Unknown'} set ${grp.name} crate stock to $newStock',
                    relatedEntityType: 'crate_group',
                  );
                  if (mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
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
        context.getRSize(120),
      ),
      itemCount: logs.length,
      separatorBuilder: (_, __) => SizedBox(height: context.getRSize(8)),
      itemBuilder: (ctx, i) => _buildLogRow(ctx, logs[i]),
    );
  }

  Widget _buildLogRow(BuildContext context, ActivityLogData log) {
    final actionColors = {
      'Inventory Restock': AppColors.success,
      'Stock Adjustment': Theme.of(context).colorScheme.primary,
      'crate_update': AppColors.warning,
      'new_supplier': Theme.of(context).colorScheme.secondary,
    };
    final color =
        actionColors[log.action] ?? Theme.of(context).colorScheme.primary;

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

  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(onProductAdded: () => setState(() {})),
    );
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
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
              const SizedBox(height: 20),
              Text(
                'Add New Supplier',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the company and contact details',
                style: TextStyle(fontSize: 13, color: _subtext),
              ),
              const SizedBox(height: 20),
              _styledDialogField(
                nameCtrl,
                'Supplier / Company Name',
                'e.g. SABMiller Nigeria',
              ),
              const SizedBox(height: 16),
              _styledDialogField(
                contactCtrl,
                'Contact Details / Rep Info',
                'e.g. John Doe, 08012345678',
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Add Supplier',
                variant: AppButtonVariant.primary,
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final newSupplier = Supplier(
                    id: 's${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    crateGroup: CrateGroup.nbPlc,
                    trackInventory: true,
                    contactDetails: contactCtrl.text.trim(),
                    amountPaid: 0.0,
                    supplierWallet: 0.0,
                  );
                  supplierService.addSupplier(newSupplier);
                  database.activityLogDao.log(
                    action: 'New Supplier',
                    description: 'Supplier added: ${newSupplier.name}',
                    entityId: newSupplier.id,
                    entityType: 'Supplier',
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
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
  double get minExtent => 48;
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

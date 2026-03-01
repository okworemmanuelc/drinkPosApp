import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../data/models/crate_group.dart';
import '../data/models/supplier.dart';
import '../data/models/inventory_item.dart';
import '../data/models/crate_stock.dart';
import '../data/models/inventory_log.dart';
import '../data/inventory_data.dart';
import '../../pos/data/products_data.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSupplierId = 'all';
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        drawer: const AppDrawer(activeRoute: 'inventory'),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildSummaryCards(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductsTab(),
                    _buildCratesTab(),
                    _buildLogTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildAddFab(),
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 16,
                  decoration: BoxDecoration(
                    color: blueMain,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blueLight, blueMain]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.boxesStacked,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Stock Management',
                style: TextStyle(
                  fontSize: 11,
                  color: blueMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showAddSupplierDialog,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: blueMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: blueMain.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.buildingColumns,
                  size: 13,
                  color: blueMain,
                ),
                const SizedBox(width: 6),
                Text(
                  '+ Supplier',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isDark ? blueLight : blueDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── SUMMARY CARDS ─────────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final totalItems = kInventoryItems.length;
    final lowStock = kInventoryItems
        .where((i) => i.stock <= i.lowStockThreshold)
        .length;
    final outOfStock = kInventoryItems.where((i) => i.stock == 0).length;
    final totalCrates = _activeCrateGroups.fold<double>(0, (s, c) => s + c.available);

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _summaryCard(
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
          const SizedBox(width: 10),
          _summaryCard(
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
          const SizedBox(width: 10),
          _summaryCard(
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
          const SizedBox(width: 10),
          _summaryCard(
            'Empty Crates',
            '${totalCrates.toInt()}',
            FontAwesomeIcons.beerMugEmpty,
            success,
            isActive: _tabController.index == 1,
            onTap: () => setState(() {
              _tabController.animateTo(1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color,
      {bool isActive = false, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDark ? dCard : lCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isActive ? color : color.withValues(alpha: 0.2),
                width: isActive ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: _subtext,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Divider(height: 1, color: _border),
          TabBar(
            controller: _tabController,
            labelColor: blueMain,
            unselectedLabelColor: _subtext,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            indicatorColor: blueMain,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Empty Crates'),
              Tab(text: 'Activity Log'),
            ],
          ),
        ],
      ),
    );
  }

  // ── PRODUCTS TAB ──────────────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    return Column(
      children: [
        _buildSupplierFilter(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _filteredItems.length,
            itemBuilder: (_, i) => _buildProductRow(_filteredItems[i]),
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

    if (_stockFilter == 'low') {
      return list
          .where((i) => i.stock > 0 && i.stock <= i.lowStockThreshold)
          .toList();
    } else if (_stockFilter == 'out') {
      return list.where((i) => i.stock == 0).toList();
    }
    return list;
  }

  List<CrateStock> get _activeCrateGroups {
    return kCrateStocks.where((cs) {
      return kInventoryItems.any((item) {
        final supplier = kSuppliers.firstWhere(
          (s) => s.id == item.supplierId,
          orElse: () =>
              Supplier(id: '', name: '', crateGroup: CrateGroup.nbPlc),
        );
        final isGlass = item.subtitle.toLowerCase() == 'crate' ||
            kProducts.any((p) =>
                p['name'] == item.productName &&
                p['category'] == 'Glass Crates');
        return supplier.crateGroup == cs.group && isGlass;
      });
    }).toList();
  }

  Widget _buildSupplierFilter() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _filterChip('All', 'all'),
                ...kSuppliers.map(
                  (s) => _filterChip(s.name.split(' ').first, s.id),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String id) {
    final active = _selectedSupplierId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSupplierId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: active ? blueMain : (_isDark ? dCard : lCard),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? blueMain : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : _subtext,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(InventoryItem item) {
    final isLow = item.stock > 0 && item.stock <= item.lowStockThreshold;
    final isOut = item.stock == 0;
    final supplier = kSuppliers.firstWhere(
      (s) => s.id == item.supplierId,
      orElse: () =>
          Supplier(id: '', name: 'Unknown', crateGroup: CrateGroup.nbPlc),
    );
    final crateStock = kCrateStocks.firstWhere(
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
      onTap: () => _showUpdateStockDialog(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 10 : 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supplier.name,
                      style: TextStyle(fontSize: 12, color: _subtext),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.beerMugEmpty,
                          size: 10,
                          color: supplier.crateGroup.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Empty crates (${supplier.crateGroup.label}): ${crateStock.available.toInt()} available',
                            style: TextStyle(fontSize: 11, color: _subtext),
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
                  Text(
                    item.stock.toStringAsFixed(item.stock % 1 == 0 ? 0 : 1),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isOut
                          ? danger
                          : isLow
                          ? const Color(0xFFF59E0B)
                          : _text,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(fontSize: 11, color: _subtext),
                  ),
                  const SizedBox(height: 4),
                  const Icon(FontAwesomeIcons.penToSquare, size: 12, color: blueMain),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CRATES TAB ────────────────────────────────────────────────────────────────
  Widget _buildCratesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  const Icon(
                    FontAwesomeIcons.circleInfo,
                    size: 14,
                    color: blueMain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How Empty Crates Work',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Empty crates are pooled by supplier group — all bottles from the same group share the same crate type. When a customer returns crates, add them to the relevant group. When restocking a product, crates are drawn from that group.',
                style: TextStyle(fontSize: 13, color: _subtext, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Crate Groups',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            GestureDetector(
              onTap: _showAddSupplierDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: blueMain.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FontAwesomeIcons.plus, size: 12, color: blueMain),
                    const SizedBox(width: 6),
                    Text(
                      'New Group',
                      style: TextStyle(
                        fontSize: 12,
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
        const SizedBox(height: 12),
        ..._activeCrateGroups.map((cs) => _buildCrateGroupCard(cs)),
      ],
    );
  }

  Widget _buildCrateGroupCard(CrateStock cs) {
    final linkedProducts = kInventoryItems
        .where((item) {
          final supplier = kSuppliers.firstWhere(
            (s) => s.id == item.supplierId,
            orElse: () =>
                Supplier(id: '', name: 'Unknown', crateGroup: CrateGroup.nbPlc),
          );
          return supplier.crateGroup == cs.group;
        })
        .map((i) => i.productName)
        .toList();

    final linkedSuppliers = kSuppliers
        .where((s) => s.crateGroup == cs.group)
        .map((s) => s.name)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.group.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.group.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    FontAwesomeIcons.beerMugEmpty,
                    color: cs.group.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cs.group.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linkedSuppliers.isEmpty
                            ? 'No suppliers linked'
                            : linkedSuppliers.join(', '),
                        style: TextStyle(fontSize: 12, color: _subtext),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${cs.available.toInt()}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.available == 0 ? danger : _text,
                      ),
                    ),
                    Text(
                      'crates',
                      style: TextStyle(fontSize: 11, color: _subtext),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (linkedProducts.isNotEmpty) ...[
            Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked Products: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _subtext,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      linkedProducts.join(', '),
                      style: TextStyle(fontSize: 12, color: _subtext),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showUpdateCratesDialog(cs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.group.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.group.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.group.color,
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
  Widget _buildLogTab() {
    if (kInventoryLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.clockRotateLeft, size: 48, color: _border),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates will appear here with date, time, and user',
              style: TextStyle(color: _subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sorted = [...kInventoryLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildLogRow(sorted[i]),
    );
  }

  Widget _buildLogRow(InventoryLog log) {
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.user} · ${_formatLogTime(log.timestamp)}',
                  style: TextStyle(fontSize: 11, color: _subtext),
                ),
                if (log.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.note!,
                    style: TextStyle(
                      fontSize: 11,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: diff >= 0 ? success : danger,
                ),
              ),
              Text(
                '${log.previousValue.toInt()} → ${log.newValue.toInt()}',
                style: TextStyle(fontSize: 10, color: _subtext),
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
  Widget _buildAddFab() {
    return GestureDetector(
      onTap: _showAddProductDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [blueLight, blueMain],
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FontAwesomeIcons.plus, color: Colors.white, size: 16),
            SizedBox(width: 10),
            Text(
              'Add Product',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                                color: item.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(item.icon, color: item.color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update Stock',
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
                          'Action',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _actionChip(
                              'restock',
                              'Restock',
                              action,
                              (v) => setB(() => action = v),
                            ),
                            const SizedBox(width: 8),
                            _actionChip(
                              'adjustment',
                              'Adjust',
                              action,
                              (v) => setB(() => action = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          action == 'restock' ? 'Quantity to Add' : 'Set Stock To',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _subtext,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                              borderSide: const BorderSide(color: blueMain, width: 2),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            suffixText: item.subtitle,
                            suffixStyle: TextStyle(color: _subtext, fontSize: 14),
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
                              borderSide: const BorderSide(color: blueMain, width: 2),
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
                              border: Border.all(color: success.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FontAwesomeIcons.tag, size: 14, color: success),
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
                        final newQty = action == 'restock'
                            ? item.stock + entered
                            : entered;
                        final diff = newQty - item.stock;

                        final log = InventoryLog(
                          timestamp: DateTime.now(),
                          user: 'John Cashier',
                          itemId: item.id,
                          itemName: item.productName,
                          action: action,
                          previousValue: item.stock,
                          newValue: newQty,
                          note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                        );

                        // Adjust crate stock if it's a "Glass Crates" product
                        // 1. Check product category
                        final productData = kProducts.firstWhere(
                          (p) => p['name'] == item.productName,
                          orElse: () => <String, dynamic>{},
                        );

                        setState(() {
                          item.stock = newQty;
                          kInventoryLogs.add(log);

                          if (productData.isNotEmpty &&
                              productData['category'] == 'Glass Crates') {
                            final supplier = kSuppliers.firstWhere(
                              (s) => s.id == item.supplierId,
                              orElse: () => Supplier(
                                  id: '', name: '', crateGroup: CrateGroup.premium),
                            );

                            final cStockIndex = kCrateStocks.indexWhere(
                                (c) => c.group == supplier.crateGroup);

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
      orElse: () => {
        'price': 0,
        'wholesale_price': 0,
        'category': 'Other',
      },
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                              child: Icon(FontAwesomeIcons.tag, color: success, size: 20),
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
                            fontSize: 18,
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
                              borderSide: const BorderSide(color: blueMain, width: 2),
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
                        backgroundColor: success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final newPrice = int.tryParse(priceCtrl.text) ?? existingParams['price'];
                        setState(() {
                          final idx = kProducts.indexWhere((p) => p['name'] == item.productName);
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? blueMain : (_isDark ? dCard : lCard),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? blueMain : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: active ? Colors.white : _subtext,
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
          bottom: MediaQuery.of(context).viewInsets.bottom,
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
                    borderSide: const BorderSide(color: blueMain, width: 2),
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
                    borderSide: const BorderSide(color: blueMain, width: 2),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
    String selectedSupplierId = kSuppliers.first.id;
    final stockCtrl = TextEditingController(text: '0');
    final retailPriceCtrl = TextEditingController();
    final wholesalePriceCtrl = TextEditingController();
    final buyingPriceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                        _inputField('Product Name', nameCtrl, 'e.g. Trophy Lager'),
                const SizedBox(height: 12),
                _inputField(
                  'Type / Packaging',
                  subtitleCtrl,
                  'e.g. Crate, Can, Keg',
                ),
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
                      onChanged: (v) => setB(() => selectedSupplierId = v!),
                      items: kSuppliers
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                    ),
                  ),
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
                          stock: double.tryParse(stockCtrl.text) ?? 0,
                        );
                        final log = InventoryLog(
                          timestamp: DateTime.now(),
                          user: 'John Cashier',
                          itemId: newItem.id,
                          itemName: newItem.productName,
                          action: 'restock',
                          previousValue: 0,
                          newValue: newItem.stock,
                          note: 'New product added to inventory',
                        );
                        setState(() {
                          kInventoryItems.add(newItem);
                          kInventoryLogs.add(log);
                          
                          // Also add to POS products data
                          kProducts.add({
                            'name': newItem.productName,
                            'subtitle': newItem.subtitle,
                            'price': int.tryParse(retailPriceCtrl.text) ?? 0,
                            'wholesale_price': int.tryParse(wholesalePriceCtrl.text) ?? 0,
                            'buying_price': int.tryParse(buyingPriceCtrl.text) ?? 0,
                            'category': 'Other',
                            'icon': newItem.icon,
                            'color': newItem.color,
                          });
                        });
                        Navigator.pop(ctx);
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
    CrateGroup selectedGroup = CrateGroup.nbPlc;
    bool trackInventory = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? dSurface : lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                  'Choose a crate group so empty crates are tracked correctly',
                  style: TextStyle(fontSize: 13, color: _subtext),
                ),
                const SizedBox(height: 20),
                _inputField(
                  'Supplier / Company Name',
                  nameCtrl,
                  'e.g. SABMiller Nigeria',
                ),
                const SizedBox(height: 16),
                Text(
                  'Crate Group',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CrateGroup.values.map((g) {
                    final active = selectedGroup == g;
                    return GestureDetector(
                      onTap: () => setB(() => selectedGroup = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? g.color.withValues(alpha: 0.15)
                              : (_isDark ? dCard : lCard),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active ? g.color : _border,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: g.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              g.label,
                              style: TextStyle(
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: active ? g.color : _subtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setB(() => trackInventory = !trackInventory),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: trackInventory ? blueMain : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: trackInventory ? blueMain : _border,
                            width: 2,
                          ),
                        ),
                        child: trackInventory
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Track inventory for this supplier',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
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
                      final newSupplier = Supplier(
                        id: 's${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        crateGroup: selectedGroup,
                        trackInventory: trackInventory,
                      );
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: newSupplier.id,
                        itemName: newSupplier.name,
                        action: 'new_supplier',
                        previousValue: 0,
                        newValue: 0,
                        note: 'Crate group: ${selectedGroup.label}',
                      );
                      setState(() {
                        kSuppliers.add(newSupplier);
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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

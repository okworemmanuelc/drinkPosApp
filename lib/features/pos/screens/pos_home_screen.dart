import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../inventory/data/services/supplier_service.dart';
import '../../../shared/services/cart_service.dart';
import '../../customers/data/models/customer.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/fluid_menu.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/database/app_database.dart';

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});
  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen>
    with TickerProviderStateMixin {
  String _selectedSupplierId = 'All';
  CustomerGroup _selectedGroup = CustomerGroup.retailer;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<CategoryData> _dbCategories = [];
  int? _selectedCategoryId;

  // All products from the database (loaded once in initState, not inside build)
  List<ProductDataWithStock> _allProducts = [];
  StreamSubscription<List<ProductDataWithStock>>? _productsSub;

  // Timer used for debounced search (waits 300ms after typing stops)
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _subscribeToProducts(categoryId: null); // load all products at start
    cartService.activeCustomer.addListener(_onCustomerSelected);
  }

  // Subscribes to the product stream for a given category.
  // Cancels the old subscription first so we don't pile up listeners.
  void _subscribeToProducts({int? categoryId}) {
    _productsSub?.cancel();
    _productsSub = database.inventoryDao
        .watchProductsByCategory(categoryId)
        .listen((data) {
      if (mounted) setState(() => _allProducts = data);
    });
  }

  Future<void> _loadCategories() async {
    final cats = await database.select(database.categories).get();
    setState(() {
      _dbCategories = cats;
    });
  }

  void _onCustomerSelected() {
    final customer = cartService.activeCustomer.value;
    if (customer != null) {
      setState(() {
        _selectedGroup = customer.customerGroup;
      });
    }
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _searchDebounce?.cancel();
    cartService.activeCustomer.removeListener(_onCustomerSelected);
    _searchController.dispose();
    super.dispose();
  }

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _cardBg => _isDark ? dCard : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => SharedScaffold(
        activeRoute: 'pos',
        backgroundColor: _bg,
        appBar: _buildAppBar(context),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context),
              if (_isSearching) _buildSearchField(),
              _buildFilterBar(),
              Expanded(child: _buildGrid()),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        icon: FontAwesomeIcons.beerMugEmpty,
        title: 'Ribaplus POS',
        subtitle: 'Point of Sale',
      ),
      actions: [
        _iconBtn(
          context,
          _isSearching
              ? FontAwesomeIcons.xmark
              : FontAwesomeIcons.magnifyingGlass,
          () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) {
              _searchQuery = '';
              _searchController.clear();
            }
          }),
          size: 17,
        ),
        const NotificationBell(),
        SizedBox(width: context.spacingS),
      ],
    );
  }

  Widget _iconBtn(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    double size = 18,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: context.getRSize(40),
        height: context.getRSize(40),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: context.getRSize(size),
          color: _subtext,
        ), // RESPONSIVE
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        context.spacingM,
        context.spacingXs,
        context.spacingM,
        context.spacingM,
      ),
      child: Row(
        children: [
          // Pricing Tier Dropdown
          Expanded(
            flex: 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FluidMenu<CustomerGroup>(
                  value: _selectedGroup,
                  items: CustomerGroup.values.map((g) {
                    String label = g == CustomerGroup.retailer
                        ? 'Retail'
                        : (g == CustomerGroup.bulkBreaker
                            ? 'Bulk'
                            : 'Distr.');
                    return FluidMenuItem(value: g, label: label);
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGroup = val);
                  },
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _showTip(
                      'Pricing Tiers 🏷️',
                      'Switch between Retail, Bulk breaker, and Distributor prices. All product prices update instantly based on your selection.',
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: blueMain,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacingS),

          // Supplier Filter Dropdown
          Expanded(
            flex: 5,
            child: FluidMenu<String>(
              value: _selectedSupplierId,
              items: [
                const FluidMenuItem(value: 'All', label: 'All Suppliers'),
                ...supplierService.getAll().map((s) => FluidMenuItem(
                      value: s.id,
                      label: s.name,
                    )),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedSupplierId = val);
              },
            ),
          ),
          SizedBox(width: context.spacingS),

          // Quick Sale Button
          GestureDetector(
            onTap: () => _showQuickSaleModal(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingM,
                    vertical: context.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: blueMain.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(context.radiusM),
                    border: Border.all(color: blueMain.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    FontAwesomeIcons.bolt,
                    size: context.getRSize(18),
                    color: blueMain,
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _showTip(
                      'Quick Sale ⚡',
                      'Tap to manually enter items not in inventory. Perfect for one-off sales!',
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: blueMain,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER BAR ───────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Divider(height: 1, color: _border),
          SizedBox(
            height: context.getRSize(54),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingM,
                vertical: context.spacingS,
              ),
              itemCount: _dbCategories.length + 1,
              itemBuilder: (_, i) {
                final isAll = i == 0;
                final cat = isAll ? null : _dbCategories[i - 1];
                final active = isAll ? _selectedCategoryId == null : _selectedCategoryId == cat?.id;
                final label = isAll ? 'All' : cat!.name;
                
                return Padding(
                  padding: EdgeInsets.only(right: context.spacingS),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryId = cat?.id);
                      // Re-subscribe the stream filtered to the chosen category.
                      // null means "all categories".
                      _subscribeToProducts(categoryId: cat?.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacingM,
                        vertical: context.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: active ? blueMain : (_isDark ? dCard : lCard),
                        borderRadius: BorderRadius.circular(context.radiusL),
                        border: Border.all(
                          color: active ? blueMain : _border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: context.getRFontSize(13),
                            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                            color: active ? Colors.white : _subtext,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── PRODUCT GRID ─────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    // Filter the already-loaded list in memory.
    // The DB query already handles category, so here we only apply
    // the text search and stock/availability checks.
    var items = _allProducts
        .where((item) =>
            item.totalStock > 0 &&
            item.product.isAvailable &&
            !item.product.isDeleted)
        .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((item) =>
              item.product.name.toLowerCase().contains(q) ||
              (item.product.subtitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.magnifyingGlass, size: context.getRSize(48), color: _border),
            SizedBox(height: context.spacingM),
            Text(
              'No products found',
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 360 ? 2 : (screenWidth > 500 ? 4 : 3);
    final aspect = screenWidth < 360 ? 0.75 : (screenWidth > 500 ? 0.68 : 0.68);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        context.spacingM,
        context.spacingM,
        context.spacingM,
        context.getRSize(100),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspect,
        crossAxisSpacing: context.spacingM,
        mainAxisSpacing: context.spacingM,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: cartService,
        builder: (context, cart, _) => _buildProductCard(items[i].product, cart),
      ),
    );
  }

  Widget _buildProductCard(
    ProductData product,
    List<Map<String, dynamic>> cart,
  ) {
    final int priceKobo = database.catalogDao.getPriceForCustomerGroup(
      product, 
      _selectedGroup == CustomerGroup.retailer ? 'retail' : (_selectedGroup == CustomerGroup.bulkBreaker ? 'bulk_breaker' : 'distributor')
    );
    final price = priceKobo / 100.0;
    
    final cartIdx = cart.indexWhere((c) => c['id'] == product.id);
    final inCart = cartIdx != -1;
    final qty = inCart ? cart[cartIdx]['qty'] : 0.0;
    
    final Color accent = product.colorHex != null 
        ? Color(int.parse(product.colorHex!.replaceFirst('#', '0xFF')))
        : blueMain;

    return GestureDetector(
      onTap: () {
        cartService.addItem(product, qty: 1.0);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(FontAwesomeIcons.circleCheck, color: Colors.white, size: context.getRSize(16)),
                SizedBox(width: context.getRSize(12)),
                Text(
                  '${product.name} added to cart',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: blueMain,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(context.getRSize(16)),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? blueMain : _border,
            width: inCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: inCart
                  ? blueMain.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.getRSize(10),
                context.getRSize(16),
                context.getRSize(10),
                context.getRSize(10),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconData(product.iconCodePoint ?? 0xf0fc, fontFamily: 'FontAwesomeSolid', fontPackage: 'font_awesome_flutter'),
                        size: context.getRSize(28),
                        color: accent,
                      ),
                    ),
                  ),
                  SizedBox(height: context.getRSize(12)),
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: context.getRFontSize(12),
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (product.subtitle != null) ...[
                    SizedBox(height: context.getRSize(2)),
                    Text(
                      product.subtitle!,
                      style: TextStyle(
                        fontSize: context.getRFontSize(10),
                        color: _subtext,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: context.getRSize(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(8),
                      vertical: context.getRSize(4),
                    ),
                    decoration: BoxDecoration(
                      color: _isDark ? dBg : lBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatCurrency(price),
                        style: TextStyle(
                          fontSize: context.getRFontSize(11),
                          fontWeight: FontWeight.w800,
                          color: _isDark ? blueLight : blueDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (inCart)
              Positioned(
                top: context.getRSize(8),
                right: context.getRSize(8),
                child: Container(
                  padding: EdgeInsets.all(context.getRSize(6)),
                  decoration: const BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    qty.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.getRFontSize(10),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!inCart)
              Positioned(
                top: context.getRSize(8),
                right: context.getRSize(8),
                child: Container(
                  width: context.getRSize(24),
                  height: context.getRSize(24),
                  decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
                  child: Icon(
                    Icons.add,
                    size: context.getRSize(14),
                    color: _subtext,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── SEARCH FIELD ──────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        0,
        context.getRSize(16),
        context.getRSize(12),
      ), // RESPONSIVE
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) {
          // Cancel the previous timer every time the user types a new letter.
          // Only update the list 300ms after the user STOPS typing.
          // This prevents a rebuild on every single keystroke.
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _searchQuery = v);
          });
        },
        style: TextStyle(
          fontSize: context.getRFontSize(14),
          color: _text,
        ), // RESPONSIVE
        decoration: InputDecoration(
          hintText: 'Search products by name...',
          hintStyle: TextStyle(color: _subtext),
          prefixIcon: Icon(
            FontAwesomeIcons.magnifyingGlass,
            size: context.getRSize(16),
            color: _subtext,
          ), // RESPONSIVE
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(12),
          ), // RESPONSIVE
        ),
      ),
    );
  }

  // ── QUICK SALE MODAL ─────────────────────────────────────────────────────
  void _showQuickSaleModal() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Quick Sale ⚡',
          style: TextStyle(color: _text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modalField(nameCtrl, 'Item Name', FontAwesomeIcons.tag),
            SizedBox(height: ctx.getRSize(12)),
            _modalField(qtyCtrl, 'Quantity', FontAwesomeIcons.cubes, isNumber: true),
            SizedBox(height: ctx.getRSize(12)),
            _modalField(priceCtrl, 'Price', FontAwesomeIcons.nairaSign, isNumber: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blueMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && qtyCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                final product = {
                  'name': nameCtrl.text,
                  'subtitle': 'Quick Sale',
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'icon': FontAwesomeIcons.bolt,
                  'color': blueMain,
                  'category': 'Other',
                };
                cartService.addItem(product, qty: double.tryParse(qtyCtrl.text) ?? 1.0);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Send to Cart'),
          ),
        ],
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: _text, fontSize: context.getRFontSize(14)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _subtext),
        prefixIcon: Icon(icon, size: context.getRSize(16), color: _subtext),
        filled: true,
        fillColor: _isDark ? dCard : lCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: context.getRSize(16), vertical: context.getRSize(12)),
      ),
    );
  }

  void _showTip(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _surface,
        title: Row(
          children: [
            const Icon(FontAwesomeIcons.circleInfo, color: blueMain, size: 20),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: _subtext, fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: blueMain, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


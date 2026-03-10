import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../data/products_data.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/models/inventory_item.dart';
import '../../customers/data/models/customer.dart';
import '../../../core/utils/stock_calculator.dart';
import 'cart_screen.dart';

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});
  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen>
    with TickerProviderStateMixin {
  String _filter = 'All';
  bool _isWholesale = false;
  Customer? _activeCustomer;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final double _crateDeposit = 1500.0;
  late AnimationController _fabAnim;

  final List<Map<String, dynamic>> _cart = [
    {
      'name': 'Star Lager',
      'subtitle': 'Crate',
      'price': 5000,
      'qty': 1.0,
      'icon': FontAwesomeIcons.beerMugEmpty,
      'color': const Color(0xFFF59E0B),
      'category': 'Glass Crates',
    },
    {
      'name': 'Heineken',
      'subtitle': 'Can',
      'price': 8500,
      'qty': 2.5,
      'icon': FontAwesomeIcons.wineBottle,
      'color': const Color(0xFF10B981),
      'category': 'Cans & PET',
    },
  ];

  final List<String> _filters = ['All', 'Glass Crates', 'Cans & PET', 'Kegs'];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnim.forward();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
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
      builder: (_, _, _) => Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(context),
        drawer: const AppDrawer(activeRoute: 'pos'),
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
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
                  width: context.getRSize(22), // RESPONSIVE
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: context.getRSize(16), // RESPONSIVE
                  decoration: BoxDecoration(
                    color: blueMain,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: context.getRSize(22), // RESPONSIVE
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
            padding: EdgeInsets.all(context.getRSize(8)), // RESPONSIVE
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
            child: Icon(
              FontAwesomeIcons.beerMugEmpty,
              color: Colors.white,
              size: context.getRSize(16), // RESPONSIVE
            ),
          ),
          SizedBox(width: context.getRSize(12)), // RESPONSIVE
          Expanded(
            // RESPONSIVE to prevent title overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'BrewFlow',
                    style: TextStyle(
                      fontSize: context.getRFontSize(18), // RESPONSIVE
                      fontWeight: FontWeight.w800,
                      color: _text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  'Point of Sale',
                  style: TextStyle(
                    fontSize: context.getRFontSize(11), // RESPONSIVE
                    color: blueMain,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
        Stack(
          alignment: Alignment.center,
          children: [
            _iconBtn(
              context,
              FontAwesomeIcons.cartShopping,
              () => _openCart(),
              size: 17,
            ),
            if (_cart.isNotEmpty)
              Positioned(
                right: context.getRSize(6),
                top: context.getRSize(6),
                child: Container(
                  width: context.getRSize(18),
                  height: context.getRSize(18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 2),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.getRFontSize(9), // RESPONSIVE
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: context.getRSize(8)), // RESPONSIVE
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
        width: context.getRSize(40), // RESPONSIVE
        height: context.getRSize(40), // RESPONSIVE
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: context.getRSize(size),
          color: _subtext,
        ), // RESPONSIVE
      ),
    );
  }

  // ── HEADER STRIP ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(4),
        context.getRSize(16),
        context.getRSize(16),
      ), // RESPONSIVE
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(16),
                  vertical: context.getRSize(10),
                ), // RESPONSIVE
                decoration: BoxDecoration(
                  color: blueMain.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: blueMain.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FontAwesomeIcons.bolt,
                      size: context.getRSize(14),
                      color: blueMain,
                    ), // RESPONSIVE
                    SizedBox(width: context.getRSize(8)), // RESPONSIVE
                    Flexible(
                      child: Text(
                        'Quick Sale',
                        style: TextStyle(
                          fontSize: context.getRFontSize(13), // RESPONSIVE
                          fontWeight: FontWeight.w700,
                          color: _isDark ? blueLight : blueDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.all(context.getRSize(4)), // RESPONSIVE
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pricePill(context, 'Retail', !_isWholesale),
                SizedBox(width: context.getRSize(4)), // RESPONSIVE
                _pricePill(context, 'Wholesale', _isWholesale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(BuildContext context, String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isWholesale = label == 'Wholesale'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.getRSize(16),
          vertical: context.getRSize(8),
        ), // RESPONSIVE
        decoration: BoxDecoration(
          color: active ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.getRFontSize(12), // RESPONSIVE
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? blueMain : _subtext,
          ),
        ),
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
            height: context.getRSize(54), // RESPONSIVE
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: context.getRSize(16),
                vertical: context.getRSize(10),
              ), // RESPONSIVE
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final active = _filter == _filters[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: context.getRSize(10),
                  ), // RESPONSIVE
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = _filters[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(18),
                        vertical: context.getRSize(6),
                      ), // RESPONSIVE
                      decoration: BoxDecoration(
                        color: active ? blueMain : (_isDark ? dCard : lCard),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? blueMain : _border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _filters[i],
                          style: TextStyle(
                            fontSize: context.getRFontSize(13), // RESPONSIVE
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
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
  Map<String, dynamic> _inventoryItemToProduct(InventoryItem item) {
    // Match against kProducts by name to get price info
    final existing = kProducts.firstWhere(
      (p) => p['name'] == item.productName,
      orElse: () => {'price': 0, 'wholesale_price': 0, 'category': 'Other'},
    );
    return {
      'name': item.productName,
      'subtitle': item.subtitle,
      'price': existing['price'] ?? 0,
      'wholesale_price': existing['wholesale_price'] ?? 0,
      'category': existing['category'] ?? 'Other',
      'icon': item.icon,
      'color': item.color,
      'stock': item.stock,
    };
  }

  Widget _buildGrid() {
    final allProducts = kInventoryItems
        .where((i) => i.stock > 0) // only show in-stock items on POS
        .map(_inventoryItemToProduct)
        .toList();

    var shown = _filter == 'All'
        ? allProducts
        : allProducts.where((p) => p['category'] == _filter).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      shown = shown
          .where(
            (p) =>
                (p['name'] as String).toLowerCase().contains(q) ||
                (p['subtitle'] as String).toLowerCase().contains(q),
          )
          .toList();
    }

    if (shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.magnifyingGlass, size: 48, color: _border),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term',
              style: TextStyle(color: _subtext, fontSize: 13),
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
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(16),
        context.getRSize(100),
      ), // RESPONSIVE
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspect,
        crossAxisSpacing: context.getRSize(12), // RESPONSIVE
        mainAxisSpacing: context.getRSize(12), // RESPONSIVE
      ),
      itemCount: shown.length,
      itemBuilder: (_, i) => _buildProductCard(shown[i]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final price = _isWholesale
        ? (product['wholesale_price'] ?? product['price'])
        : product['price'];
    final cartIdx = _cart.indexWhere((c) => c['name'] == product['name']);
    final inCart = cartIdx != -1;
    final qty = inCart ? _cart[cartIdx]['qty'] : 0.0;
    final Color accent = product['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (inCart) {
            _cart[cartIdx]['qty'] += 1.0;
          } else {
            _cart.add({
              'name': product['name'],
              'subtitle': product['subtitle'],
              'price': price,
              'qty': 1.0,
              'icon': product['icon'],
              'color': product['color'],
              'category': product['category'],
            });
          }
        });
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
              ), // RESPONSIVE
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
                        product['icon'] as IconData,
                        size: context.getRSize(28), // RESPONSIVE
                        color: accent,
                      ),
                    ),
                  ),
                  SizedBox(height: context.getRSize(12)), // RESPONSIVE
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontSize: context.getRFontSize(12), // RESPONSIVE
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.getRSize(2)), // RESPONSIVE
                  Text(
                    product['subtitle'],
                    style: TextStyle(
                      fontSize: context.getRFontSize(10),
                      color: _subtext,
                    ), // RESPONSIVE
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.getRSize(8)), // RESPONSIVE
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(8),
                      vertical: context.getRSize(4),
                    ), // RESPONSIVE
                    decoration: BoxDecoration(
                      color: _isDark ? dBg : lBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      // RESPONSIVE
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₦${fmtNumber(price)}',
                        style: TextStyle(
                          fontSize: context.getRFontSize(11), // RESPONSIVE
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
                top: context.getRSize(8), // RESPONSIVE
                right: context.getRSize(8), // RESPONSIVE
                child: Container(
                  padding: EdgeInsets.all(context.getRSize(6)), // RESPONSIVE
                  decoration: const BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    qty.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.getRFontSize(10), // RESPONSIVE
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!inCart)
              Positioned(
                top: context.getRSize(8), // RESPONSIVE
                right: context.getRSize(8), // RESPONSIVE
                child: Container(
                  width: context.getRSize(24), // RESPONSIVE
                  height: context.getRSize(24), // RESPONSIVE
                  decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
                  child: Icon(
                    Icons.add,
                    size: context.getRSize(14),
                    color: _subtext,
                  ), // RESPONSIVE
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    final total = _cart.fold<double>(
      0,
      (s, i) =>
          s + stockValue((i['price'] as int).toDouble(), i['qty'] as double),
    );
    return ScaleTransition(
      scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
      child: GestureDetector(
        onTap: _openCart,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(20),
            vertical: context.getRSize(14),
          ), // RESPONSIVE
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.cartShopping,
                color: Colors.white,
                size: context.getRSize(18), // RESPONSIVE
              ),
              SizedBox(width: context.getRSize(12)), // RESPONSIVE
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: context.getRFontSize(13), // RESPONSIVE
                    ),
                  ),
                  if (_cart.isNotEmpty)
                    Text(
                      '₦${fmtNumber(total.toInt())}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: context.getRFontSize(11), // RESPONSIVE
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (_cart.isNotEmpty) ...[
                SizedBox(width: context.getRSize(14)), // RESPONSIVE
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.getRSize(10),
                    vertical: context.getRSize(4),
                  ), // RESPONSIVE
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.getRFontSize(12), // RESPONSIVE
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── CART SCREEN NAVIGATION ───────────────────────────────────────────────────────────────
  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cart: _cart,
          crateDeposit: _crateDeposit,
          activeCustomer: _activeCustomer,
          onCustomerChanged: (customer) {
            setState(() {
              _activeCustomer = customer;
            });
          },
          onCheckoutSuccess: () {
            setState(() {
              _cart.clear();
              _activeCustomer = null;
            });
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {}); // Refresh the home screen after returning from cart
      }
    });
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
        onChanged: (v) => setState(() => _searchQuery = v),
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
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../data/products_data.dart';
import 'checkout_page.dart';

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});
  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen>
    with TickerProviderStateMixin {
  String _filter = 'All';
  bool _isWholesale = false;
  final double _customerBalance = -1500.00;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  double _crateDeposit = 1500.0;
  late AnimationController _fabAnim;

  final List<Map<String, dynamic>> _cart = [
    {
      'name': 'Star Lager',
      'subtitle': 'Crate',
      'price': 5000,
      'qty': 1.0,
      'icon': FontAwesomeIcons.beerMugEmpty,
      'color': const Color(0xFFF59E0B),
    },
    {
      'name': 'Heineken',
      'subtitle': 'Can',
      'price': 8500,
      'qty': 2.5,
      'icon': FontAwesomeIcons.wineBottle,
      'color': const Color(0xFF10B981),
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
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        drawer: const AppDrawer(activeRoute: 'pos'),
        body: Column(
          children: [
            _buildHeader(),
            if (_isSearching) _buildSearchField(),
            _buildFilterBar(),
            Expanded(child: _buildGrid()),
          ],
        ),
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  color: blueMain.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.beerMugEmpty,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BrewFlow',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Point of Sale',
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
        _iconBtn(
          _isSearching ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass,
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
              FontAwesomeIcons.cartShopping,
              () => _openCart(),
              size: 17,
            ),
            if (_cart.isNotEmpty)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 2),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {double size = 18}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: size, color: _subtext),
      ),
    );
  }

  // ── HEADER STRIP ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: blueMain.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blueMain.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.bolt, size: 14, color: blueMain),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Sale',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isDark ? blueLight : blueDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pricePill('Retail', !_isWholesale),
                const SizedBox(width: 4),
                _pricePill('Wholesale', _isWholesale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isWholesale = label == 'Wholesale'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final active = _filter == _filters[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = _filters[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
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
                            fontSize: 13,
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
  Widget _buildGrid() {
    var shown = _filter == 'All'
        ? List<Map<String, dynamic>>.from(kProducts)
        : kProducts.where((p) => p['category'] == _filter).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      shown = shown
          .where((p) =>
              (p['name'] as String).toLowerCase().contains(q) ||
              (p['subtitle'] as String).toLowerCase().contains(q))
          .toList();
    }

    if (shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.magnifyingGlass, size: 48, color: _border),
            const SizedBox(height: 16),
            Text('No products found',
                style: TextStyle(
                    color: _subtext,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text('Try a different search term',
                style: TextStyle(color: _subtext, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.80,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
                  ? blueMain.withOpacity(0.15)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        product['icon'] as IconData,
                        size: 28,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product['subtitle'],
                    style: TextStyle(fontSize: 10, color: _subtext),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isDark ? dBg : lBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₦${fmtNumber(price)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _isDark ? blueLight : blueDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    qty.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 14, color: _subtext),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    final total = _cart.fold<double>(0, (s, i) => s + (i['price'] * i['qty']));
    return ScaleTransition(
      scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
      child: GestureDetector(
        onTap: _openCart,
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
                color: blueMain.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                FontAwesomeIcons.cartShopping,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'View Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (_cart.isNotEmpty)
                    Text(
                      '₦${fmtNumber(total.toInt())}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (_cart.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  // ── CART MODAL ───────────────────────────────────────────────────────────────
  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          _cart.sort((a, b) => b['qty'].compareTo(a['qty']));
          final sub = _cart.fold<double>(
            0,
            (s, i) => s + (i['price'] * i['qty']),
          );
          final dep = _crateDeposit;
          final tot = sub + dep;
          final bg = _isDark ? dSurface : lSurface;
          final card = _isDark ? dCard : lCard;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Cart',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          Text(
                            '${_cart.length} item${_cart.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: blueMain,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_cart.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setModal(() => _cart.clear());
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: danger.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  FontAwesomeIcons.trashCan,
                                  color: danger,
                                  size: 13,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.close, color: _subtext, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: blueMain.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.userTag,
                            size: 16,
                            color: blueMain,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Walk-in Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.nairaSign,
                                  size: 11,
                                  color: _customerBalance < 0
                                      ? danger
                                      : success,
                                ),
                                Text(
                                  ' Bal: ₦${_customerBalance.abs().toStringAsFixed(0)} ${_customerBalance < 0 ? "overdue" : "credit"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _customerBalance < 0
                                        ? danger
                                        : success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _subtext,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: _border),
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.cartArrowDown,
                                size: 48,
                                color: _border,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cart is empty',
                                style: TextStyle(
                                  color: _subtext,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = _cart[i];
                            final Color c = item['color'] as Color;
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _editItem(ctx, item, setModal),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: c.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item['icon'] as IconData,
                                        color: c,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: _text,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['qty'].toStringAsFixed(1)} × ₦${fmtNumber(item['price'])}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _subtext,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₦${fmtNumber((item['price'] * item['qty']).toInt())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Column(
                    children: [
                      _totalRow('Subtotal', sub, small: true),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showEditCrateDeposit(setModal),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('Crate Deposit',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _subtext)),
                                const SizedBox(width: 6),
                                Icon(FontAwesomeIcons.penToSquare,
                                    size: 12, color: blueMain),
                              ],
                            ),
                            Text('₦${fmtNumber(dep.toInt())}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _text)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Empty Crates Received (disabled / coming soon) ──
                      Opacity(
                        opacity: 0.45,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDark ? dCard : lCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.beerMugEmpty,
                                    size: 16, color: _subtext),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Empty Crates Received',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _text)),
                                      Text('Coming soon',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: _subtext)),
                                    ],
                                  ),
                                ),
                                Icon(FontAwesomeIcons.lock,
                                    size: 14, color: _subtext),
                                const SizedBox(width: 8),
                                Container(
                                  width: 48,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isDark ? dBg : lBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Text('0',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _subtext)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 16),
                      _totalRow('Total', tot, large: true),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutPage(
                                cart: List<Map<String, dynamic>>.from(_cart),
                                subtotal: sub,
                                crateDeposit: dep,
                                total: tot,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blueLight, blueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: blueMain.withOpacity(0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                FontAwesomeIcons.checkToSlot,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool small = false,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: large ? FontWeight.bold : FontWeight.w600,
            color: large ? _text : _subtext,
          ),
        ),
        Text(
          '₦${fmtNumber(value.toInt())}',
          style: TextStyle(
            fontSize: large ? 22 : 15,
            fontWeight: FontWeight.w800,
            color: large ? blueMain : _text,
          ),
        ),
      ],
    );
  }

  // ── EDIT DIALOG ──────────────────────────────────────────────────────────────
  void _editItem(
    BuildContext ctx,
    Map<String, dynamic> item,
    StateSetter setModal,
  ) {
    final qtyCtrl = TextEditingController(text: item['qty'].toString());
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          backgroundColor: _isDark ? dSurface : lSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Quantity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['name'],
                style: const TextStyle(
                  fontSize: 13,
                  color: blueMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Row(
            children: [
              _qtyBtn(FontAwesomeIcons.minus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                if (v > 0.5) {
                  setD(() => qtyCtrl.text = (v - 0.5).toStringAsFixed(1));
                }
              }),
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              _qtyBtn(FontAwesomeIcons.plus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                setD(() => qtyCtrl.text = (v + 0.5).toStringAsFixed(1));
              }),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton.icon(
              onPressed: () {
                setModal(() => _cart.remove(item));
                setState(() {});
                Navigator.pop(dCtx);
              },
              icon: const Icon(FontAwesomeIcons.trash, color: danger, size: 15),
              label: const Text(
                'Remove',
                style: TextStyle(color: danger, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              onPressed: () {
                setModal(
                  () => item['qty'] = double.tryParse(qtyCtrl.text) ?? 1.0,
                );
                setState(() {});
                Navigator.pop(dCtx);
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: blueMain.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: blueMain.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: blueMain),
      ),
    );
  }

  // ── SEARCH FIELD ──────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(fontSize: 14, color: _text),
        decoration: InputDecoration(
          hintText: 'Search products by name...',
          hintStyle: TextStyle(color: _subtext),
          prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass,
              size: 16, color: _subtext),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ── EDIT CRATE DEPOSIT ────────────────────────────────────────────────────
  void _showEditCrateDeposit(StateSetter setModal) {
    final ctrl =
        TextEditingController(text: _crateDeposit.toInt().toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _isDark ? dSurface : lSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Edit Crate Deposit',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: _text)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: _text),
          decoration: InputDecoration(
            prefixText: '₦ ',
            prefixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _text),
            filled: true,
            fillColor: _isDark ? dCard : lCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: blueMain, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: _subtext))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final val =
                  double.tryParse(ctrl.text) ?? _crateDeposit;
              setState(() => _crateDeposit = val);
              setModal(() {});
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

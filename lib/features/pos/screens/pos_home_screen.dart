import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../inventory/data/models/inventory_item.dart';
import '../../inventory/data/inventory_data.dart';
import '../../inventory/data/services/supplier_service.dart';
import '../data/products_data.dart';
import '../../customers/data/models/customer.dart';
import '../../../shared/services/cart_service.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../core/theme/design_tokens.dart';

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});
  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen>
    with TickerProviderStateMixin {
  String _filter = 'All';
  String _selectedSupplierId = 'All';
  CustomerGroup _selectedGroup = CustomerGroup.retailer;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Glass Crates', 'Cans & PET', 'Kegs'];

  @override
  void initState() {
    super.initState();
    cartService.activeCustomer.addListener(_onCustomerSelected);
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
        title: 'BrewFlow',
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

  // ── HEADER STRIP ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        context.spacingM,
        context.spacingXs,
        context.spacingM,
        context.spacingM,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Pricing Tier Dropdown
            _buildDropdown<CustomerGroup>(
              value: _selectedGroup,
              items: CustomerGroup.values.map((g) {
                String label = g == CustomerGroup.retailer ? 'Retail' : (g == CustomerGroup.bulkBreaker ? 'Bulk Breaker' : 'Distributor');
                return DropdownMenuItem(
                  value: g,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGroup = val);
              },
            ),
            SizedBox(width: context.spacingM),
            
            // Supplier Filter Dropdown
            _buildDropdown<String>(
              value: _selectedSupplierId,
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All Suppliers')),
                ...supplierService.getAll().map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name),
                )),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedSupplierId = val);
              },
            ),
            SizedBox(width: context.spacingM),

            // Quick Sale Button
            GestureDetector(
              onTap: () => _showQuickSaleModal(),
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacingM),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(context.radiusM),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(
            FontAwesomeIcons.chevronDown,
            size: context.getRSize(12),
            color: blueMain,
          ),
          dropdownColor: _surface,
          borderRadius: BorderRadius.circular(12),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: context.getRFontSize(12),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
                child: item.child,
              ),
            );
          }).toList(),
          onChanged: onChanged,
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
                horizontal: context.spacingM,
                vertical: context.spacingS,
              ),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final active = _filter == _filters[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: context.spacingS,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = _filters[i]),
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
      orElse: () => {
        'sellingPrice': 0,
        'bulkBreakerPrice': 0,
        'distributorPrice': 0,
        'category': 'Other'
      },
    );

    double price = (existing['sellingPrice'] ?? 0).toDouble();
    if (_selectedGroup == CustomerGroup.bulkBreaker) {
      price = (existing['bulkBreakerPrice'] ?? price).toDouble();
    } else if (_selectedGroup == CustomerGroup.distributor) {
      price = (existing['distributorPrice'] ?? price).toDouble();
    }

    return {
      'name': item.productName,
      'subtitle': item.subtitle,
      'price': price,
      'sellingPrice': existing['sellingPrice'] ?? 0,
      'bulkBreakerPrice': existing['bulkBreakerPrice'] ?? 0,
      'distributorPrice': existing['distributorPrice'] ?? 0,
      'category': existing['category'] ?? 'Other',
      'icon': item.icon,
      'color': item.color,
      'stock': item.totalStock,
      'supplierId': item.supplierId,
      'crateGroupName': item.crateGroupName,
      'needsEmptyCrate': item.needsEmptyCrate,
    };
  }

  Widget _buildGrid() {
    final allProducts = kInventoryItems
        .where((i) => i.totalStock > 0) // only show in-stock items on POS
        .map(_inventoryItemToProduct)
        .toList();

    var shown = _filter == 'All'
        ? allProducts
        : allProducts.where((p) => p['category'] == _filter).toList();

    if (_selectedSupplierId != 'All') {
      shown = shown
          .where((p) => p['supplierId'] == _selectedSupplierId)
          .toList();
    }

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
            SizedBox(height: context.spacingXs),
            Text(
              'Try a different search term',
              style: context.bodySmall.copyWith(color: _subtext),
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
      itemCount: shown.length,
      itemBuilder: (_, i) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: cartService,
        builder: (context, cart, _) => _buildProductCard(shown[i], cart),
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> cart,
  ) {
    final price = (_selectedGroup == CustomerGroup.retailer)
        ? product['price']
        : (product['wholesale_price'] ?? product['price']);
    final cartIdx = cart.indexWhere((c) => c['name'] == product['name']);
    final inCart = cartIdx != -1;
    final qty = inCart ? cart[cartIdx]['qty'] : 0.0;
    final Color accent = product['color'] as Color;

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
                  '${product['name']} added to cart',
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
                        formatCurrency(price),
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
}

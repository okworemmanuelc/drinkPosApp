import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_fab.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/colors.dart';

import '../../../core/utils/responsive.dart';
import '../../../shared/services/cart_service.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../customers/data/models/customer.dart';
import '../controllers/pos_controller.dart';
import '../widgets/product_grid.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/quick_sale_modal.dart';
import '../../../shared/widgets/pin_dialog.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../core/database/app_database.dart';

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});

  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen> {
  late PosController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = PosController();
    _initWarehouse();
  }

  Future<void> _initWarehouse() async {
    final user = authService.currentUser;
    if (user != null && user.roleTier >= 5) {
      if (navigationService.lockedWarehouseId.value == null) {
        final houses = await database.select(database.warehouses).get();
        if (houses.isNotEmpty && mounted) {
          navigationService.setLockedWarehouse(houses.first.id);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
          builder: (_, mode, __) {
            
            final bgCol = Theme.of(context).scaffoldBackgroundColor;
            final surfaceCol = Theme.of(context).colorScheme.surface;
            final cardCol = Theme.of(context).cardColor;
            final textCol = Theme.of(context).colorScheme.onSurface;
            final subtextCol = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
            final borderCol = Theme.of(context).dividerColor;

            return SharedScaffold(
              activeRoute: 'pos',
              backgroundColor: bgCol,
              appBar: _buildAppBar(context, surfaceCol, textCol, subtextCol),
              floatingActionButton: context.isPhone ? _buildCartFab(context) : null,
              body: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildHeader(context, surfaceCol, textCol, subtextCol, borderCol),
                    if (_controller.isSearching) _buildSearchField(surfaceCol, cardCol, textCol, subtextCol),
                    CategoryFilterBar(
                      categories: ['All', ..._controller.categories.map((c) => c.name)],
                      selectedCategory: _controller.selectedCategoryId == null 
                          ? 'All' 
                          : _controller.categories.firstWhere((c) => c.id == _controller.selectedCategoryId).name,
                      onCategorySelected: (name) {
                        if (name == 'All') {
                          _controller.selectCategory(null);
                        } else {
                          final cat = _controller.categories.firstWhere((c) => c.name == name);
                          _controller.selectCategory(cat.id);
                        }
                      },
                      textCol: textCol,
                      borderCol: borderCol,
                    ),
                    Expanded(
                      child: ProductGrid(
                        products: _controller.filteredProducts,
                        onProductTap: (product) => _addToCart(context, product),
                        cardCol: cardCol,
                        textCol: textCol,
                        subtextCol: subtextCol,
                        borderCol: borderCol,
                        controller: _controller,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Color surfaceCol, Color textCol, Color subtextCol) {
    return AppBar(
      backgroundColor: surfaceCol,
      elevation: 0,
      leading: const MenuButton(),
      title: AppBarHeader(
        icon: FontAwesomeIcons.beerMugEmpty,
        title: 'Ribaplus POS',
        subtitle: _controller.currentWarehouseName ?? 'Point of Sale',
      ),
      actions: [
        IconButton(
          icon: Icon(
            _controller.isSearching ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass,
            size: 17,
            color: subtextCol,
          ),
          onPressed: () {
            _controller.toggleSearch();
            if (!_controller.isSearching) _searchController.clear();
          },
        ),
        if (authService.currentUser?.roleTier == 5)
          IconButton(
            icon: Icon(
              FontAwesomeIcons.warehouse,
              size: 16,
              color: navigationService.lockedWarehouseId.value == null 
                  ? subtextCol 
                  : Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Select Warehouse',
            onPressed: () => _showWarehousePicker(context, subtextCol),
          ),
        const NotificationBell(),
        SizedBox(width: context.getRSize(16)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color surfaceCol, Color textCol, Color subtextCol, Color borderCol) {
    return Container(
      color: surfaceCol,
      padding: EdgeInsets.all(context.getRSize(16)),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: AppDropdown<CustomerGroup>(
              value: _controller.selectedGroup,
              items: const [
                DropdownMenuItem(value: CustomerGroup.retailer, child: Text('Retailer')),
                DropdownMenuItem(value: CustomerGroup.wholesaler, child: Text('Wholesaler')),
              ],
              onChanged: (val) {
                if (val != null) _controller.selectGroup(val);
              },
            ),
          ),
          SizedBox(width: context.getRSize(8)),
          Expanded(
            flex: 5,
            child: AppDropdown<String>(
              value: _controller.selectedManufacturerId,
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All')),
                ..._controller.manufacturers.map((m) => DropdownMenuItem(value: m.id.toString(), child: Text(m.name))),
              ],
              onChanged: (val) {
                if (val != null) _controller.selectManufacturer(val);
              },
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          _buildQuickSaleBtn(context),
        ],
      ),
    );
  }

  Widget _buildQuickSaleBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQuickSaleModal(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.getRSize(16), vertical: context.getRSize(10)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Icon(FontAwesomeIcons.bolt, size: context.getRSize(18), color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildCartFab(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: cartService,
      builder: (context, cartItems, _) {
        if (cartItems.isEmpty) return const SizedBox.shrink();

        final double totalQty = cartItems.fold(0.0, (sum, item) => sum + (item['qty'] as num).toDouble());
        final String badgeText = totalQty == totalQty.roundToDouble()
            ? totalQty.toInt().toString()
            : totalQty.toStringAsFixed(1);

        return AppFAB(
          onPressed: () {
            navigationService.setIndex(9); // 9 corresponds to Cart tab
          },
          icon: FontAwesomeIcons.cartShopping,
          label: 'Go to Cart',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(Color surfaceCol, Color cardCol, Color textCol, Color subtextCol) {
    return Container(
      color: surfaceCol,
      padding: EdgeInsets.fromLTRB(context.getRSize(16), 0, context.getRSize(16), context.getRSize(12)),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => _controller.updateSearch(v),
        style: TextStyle(fontSize: context.getRFontSize(14), color: textCol),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: TextStyle(color: subtextCol),
          prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass, size: context.getRSize(16), color: subtextCol),
          filled: true,
          fillColor: cardCol,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
          contentPadding: EdgeInsets.symmetric(horizontal: context.getRSize(16), vertical: context.getRSize(12)),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, dynamic product) {
    cartService.addItem(product, qty: 1.0);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showQuickSaleModal(BuildContext context) async {
    // Require a manager (tier 4+) before opening the quick-sale modal
    final approver = await PinDialog.show(context, title: 'Quick Sale');
    if (approver == null) return; // cancelled or wrong PIN

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => QuickSaleModal(
        surfaceCol: Theme.of(context).colorScheme.surface,
        textCol: Theme.of(context).colorScheme.onSurface,
        subtextCol: (Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!),
        cardCol: Theme.of(context).cardColor,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }

  Future<void> _showWarehousePicker(BuildContext context, Color subtextCol) async {
    final warehouses = await database.select(database.warehouses).get();
    if (!context.mounted) return;
    final surface = Theme.of(context).colorScheme.surface;
    final text = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            bottom: ctx.bottomInset + 20,
            top: 10,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: border.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stylish Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subtextCol.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FontAwesomeIcons.warehouse,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Switch Warehouse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: warehouses.length,
                  itemBuilder: (ctx, i) {
                    final w = warehouses[i];
                    final isSelected = navigationService.lockedWarehouseId.value == w.id;
                    return InkWell(
                      onTap: () {
                        navigationService.setLockedWarehouse(w.id);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) 
                              : (Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? blueMain : border.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ] : [],
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.buildingCircleCheck,
                                    size: 22,
                                    color: isSelected ? blueMain : subtextCol.withValues(alpha: 0.5),
                                  ),
                                  Text(
                                    w.name,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}







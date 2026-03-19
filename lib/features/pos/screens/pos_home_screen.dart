import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/cart_service.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/fluid_menu.dart';
import '../../customers/data/models/customer.dart';
import '../../inventory/data/services/supplier_service.dart';
import '../controllers/pos_controller.dart';
import '../widgets/product_grid.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/quick_sale_modal.dart';

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
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, __) {
            final isDark = mode == ThemeMode.dark;
            final bgCol = isDark ? dBg : lBg;
            final surfaceCol = isDark ? dSurface : lSurface;
            final cardCol = isDark ? dCard : lCard;
            final textCol = isDark ? dText : lText;
            final subtextCol = isDark ? dSubtext : lSubtext;
            final borderCol = isDark ? dBorder : lBorder;

            return SharedScaffold(
              activeRoute: 'pos',
              backgroundColor: bgCol,
              appBar: _buildAppBar(context, surfaceCol, textCol, subtextCol),
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
      title: const AppBarHeader(
        icon: FontAwesomeIcons.beerMugEmpty,
        title: 'Ribaplus POS',
        subtitle: 'Point of Sale',
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
            child: FluidMenu<CustomerGroup>(
              value: _controller.selectedGroup,
              items: const [
                FluidMenuItem(value: CustomerGroup.retailer, label: 'Retailer'),
                FluidMenuItem(value: CustomerGroup.wholesaler, label: 'Wholesaler'),
              ],
              onChanged: (val) {
                if (val != null) _controller.selectGroup(val);
              },
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            flex: 5,
            child: FluidMenu<String>(
              value: _controller.selectedSupplierId,
              items: [
                const FluidMenuItem(value: 'All', label: 'All Suppliers'),
                ...supplierService.getAll().map((s) => FluidMenuItem(value: s.id, label: s.name)),
              ],
              onChanged: (val) {
                if (val != null) _controller.selectSupplier(val);
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
          color: blueMain.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: blueMain.withValues(alpha: 0.2)),
        ),
        child: Icon(FontAwesomeIcons.bolt, size: context.getRSize(18), color: blueMain),
      ),
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
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blueMain, width: 2)),
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

  void _showQuickSaleModal(BuildContext context) {
    final mode = themeNotifier.value;
    final isDark = mode == ThemeMode.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => QuickSaleModal(
        surfaceCol: isDark ? dSurface : lSurface,
        textCol: isDark ? dText : lText,
        subtextCol: isDark ? dSubtext : lSubtext,
        cardCol: isDark ? dCard : lCard,
        isDark: isDark,
      ),
    );
  }
}


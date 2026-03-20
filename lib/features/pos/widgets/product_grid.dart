import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/number_format.dart';
import '../../customers/data/models/customer.dart';
import '../controllers/pos_controller.dart';
import '../../../shared/services/cart_service.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductDataWithStock> products;
  final Function(ProductData) onProductTap;
  final Color cardCol;
  final Color textCol;
  final Color subtextCol;
  final Color borderCol;
  final PosController controller;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    required this.cardCol,
    required this.textCol,
    required this.subtextCol,
    required this.borderCol,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: context.getRSize(48),
              color: subtextCol.withValues(alpha: 0.3),
            ),
            SizedBox(height: context.getRSize(16)),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: context.getRFontSize(16),
                color: subtextCol,
                fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.all(context.getRSize(16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspect,
        crossAxisSpacing: context.getRSize(16),
        mainAxisSpacing: context.getRSize(16),
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return _ProductCard(
          item: item,
          onTap: () => onProductTap(item.product),
          cardCol: cardCol,
          textCol: textCol,
          subtextCol: subtextCol,
          borderCol: borderCol,
          controller: controller,
        );
      },
    );
  }
}

class _ProductCard extends StatefulWidget {
  final ProductDataWithStock item;
  final VoidCallback onTap;
  final Color cardCol;
  final Color textCol;
  final Color subtextCol;
  final Color borderCol;
  final PosController controller;

  const _ProductCard({
    required this.item,
    required this.onTap,
    required this.cardCol,
    required this.textCol,
    required this.subtextCol,
    required this.borderCol,
    required this.controller,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with TickerProviderStateMixin {
  AnimationController? _flingCtrl;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _flingCtrl?.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _handleTap() {
    // Fire product logic immediately
    widget.onTap();
    // Then launch fling particle
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final source = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height / 3),
    );
    _launchFling(source);
  }

  void _launchFling(Offset source) {
    // Clean up any previous animation
    _flingCtrl?.stop();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _flingCtrl?.dispose();

    final screenSize = MediaQuery.of(context).size;
    // Cart icon is the 5th (last) item in the 5-item bottom nav bar.
    // Its centre x ≈ screenWidth × (4.5/5) and y ≈ near the bottom.
    final target = Offset(screenSize.width * 0.9, screenSize.height - 28.0);

    _flingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _overlayEntry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _flingCtrl!,
        builder: (_, __) {
          final raw = _flingCtrl!.value;
          final t = Curves.easeIn.transform(raw);

          // X: linear from source to target
          final x = lerpDouble(source.dx, target.dx, t)!;
          // Y: parabolic arc (goes up first, then drops to target)
          final yBase = lerpDouble(source.dy, target.dy, t)!;
          final arc = -110.0 * sin(pi * raw); // upward arc
          final y = yBase + arc;

          final scale = lerpDouble(1.0, 0.35, t)!;
          final opacity = raw > 0.82 ? ((1.0 - raw) / 0.18).clamp(0.0, 1.0) : 1.0;

          return Positioned(
            left: x - 15,
            top: y - 15,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: blueMain,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: blueMain.withValues(alpha: 0.55),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _flingCtrl!.forward().then((_) {
      if (mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.item.product;
    final int priceKobo = database.catalogDao.getPriceForCustomerGroup(
      product,
      widget.controller.selectedGroup == CustomerGroup.retailer
          ? 'retail'
          : 'wholesaler',
    );
    final price = priceKobo / 100.0;
    final bool isLowStock = widget.item.totalStock <= 5;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: cartService,
      builder: (context, cartItems, _) {
        final double cartQty = cartItems
            .where((i) => i['id'] == product.id)
            .fold(0.0, (s, i) => s + (i['qty'] as num).toDouble());
        final bool inCart = cartQty > 0;
        final String badgeText = cartQty == cartQty.roundToDouble()
            ? cartQty.toInt().toString()
            : cartQty.toStringAsFixed(1);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: widget.cardCol,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: inCart ? blueMain : widget.borderCol,
                    width: inCart ? 2.0 : 1.0,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: blueMain.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Icon(
                            FontAwesomeIcons.beerMugEmpty,
                            size: context.getRSize(32),
                            color: blueMain.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(context.getRSize(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: context.getRFontSize(12),
                              fontWeight: FontWeight.w700,
                              color: widget.textCol,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.getRSize(4)),
                          Text(
                            formatCurrency(price),
                            style: TextStyle(
                              fontSize: context.getRFontSize(13),
                              fontWeight: FontWeight.w800,
                              color: blueMain,
                            ),
                          ),
                          SizedBox(height: context.getRSize(8)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Stock: ${widget.item.totalStock}',
                                style: TextStyle(
                                  fontSize: context.getRFontSize(10),
                                  color: isLowStock ? danger : widget.subtextCol,
                                  fontWeight: isLowStock
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              if (isLowStock)
                                Icon(
                                  FontAwesomeIcons.triangleExclamation,
                                  size: context.getRSize(10),
                                  color: danger,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Cart quantity badge — larger than before
            Positioned(
              top: -8,
              right: -8,
              child: AnimatedScale(
                scale: inCart ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                child: Container(
                  width: context.getRSize(30),
                  height: context.getRSize(30),
                  decoration: BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: blueMain.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.getRFontSize(11),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

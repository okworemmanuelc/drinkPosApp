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

class _ProductCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final product = item.product;
    final int priceKobo = database.catalogDao.getPriceForCustomerGroup(
      product,
      controller.selectedGroup == CustomerGroup.retailer ? 'retail' : 'wholesaler',
    );
    final price = priceKobo / 100.0;
    final bool isLowStock = item.totalStock <= 5;

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
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: inCart ? blueMain : borderCol,
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
                              color: textCol,
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
                                'Stock: ${item.totalStock}',
                                style: TextStyle(
                                  fontSize: context.getRFontSize(10),
                                  color: isLowStock ? danger : subtextCol,
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
            // Cart quantity badge
            Positioned(
              top: -6,
              right: -6,
              child: AnimatedScale(
                scale: inCart ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                child: Container(
                  width: context.getRSize(22),
                  height: context.getRSize(22),
                  decoration: BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: blueMain.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.getRFontSize(9),
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

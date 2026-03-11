import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/navigation_service.dart';
import '../../inventory/data/inventory_data.dart';
import '../../warehouse/data/models/warehouse.dart';
import 'stock_transfer_screen.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  double _calculateTotalStock(String warehouseId) {
    return kInventoryItems.fold(0.0, (sum, item) => sum + item.getStockForWarehouse(warehouseId));
  }

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'warehouse',
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: const MenuButton(),
        title: const AppBarHeader(
          icon: FontAwesomeIcons.warehouse,
          title: 'Warehouse',
          subtitle: 'Inventory Management',
        ),
        actions: [
          const NotificationBell(),
          SizedBox(width: context.getRSize(8)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [blueLight, blueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: blueMain.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'warehouse_fab',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockTransferScreen()),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(FontAwesomeIcons.rightLeft, size: 16, color: Colors.white),
          label: const Text(
            'New Stock Transfer',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                rSize(context, 16),
                rSize(context, 16),
                rSize(context, 16),
                rSize(context, 100),
              ),
              itemCount: kWarehouses.length,
              itemBuilder: (context, index) {
                final warehouse = kWarehouses[index];
                final totalStock = _calculateTotalStock(warehouse.id);
                return _buildWarehouseCard(context, warehouse, totalStock);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCard(BuildContext context, Warehouse warehouse, double totalStock) {
    return InkWell(
      onTap: () {
        navigationService.selectedWarehouseId.value = warehouse.id;
        navigationService.setIndex(2); // Inventory index
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: rSize(context, 16)),
        padding: EdgeInsets.all(rSize(context, 16)),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(rSize(context, 12)),
              decoration: BoxDecoration(
                color: blueMain.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.warehouse,
                color: blueMain,
                size: rSize(context, 20),
              ),
            ),
            SizedBox(width: rSize(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouse.name,
                    style: TextStyle(
                      fontSize: rFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  Text(
                    '${totalStock.toInt()} units available',
                    style: TextStyle(
                      fontSize: rFontSize(context, 13),
                      color: _subtext,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              FontAwesomeIcons.chevronRight,
              size: rSize(context, 14),
              color: _border,
            ),
          ],
        ),
      ),
    );
  }
}

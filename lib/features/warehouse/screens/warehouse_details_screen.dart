import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../core/utils/number_format.dart';

class WarehouseDetailsScreen extends StatefulWidget {
  final WarehouseData warehouse;

  const WarehouseDetailsScreen({super.key, required this.warehouse});

  @override
  State<WarehouseDetailsScreen> createState() => _WarehouseDetailsScreenState();
}

class _WarehouseDetailsScreenState extends State<WarehouseDetailsScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'warehouse',
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: AppBarHeader(
          icon: FontAwesomeIcons.warehouse,
          title: widget.warehouse.name,
          subtitle: widget.warehouse.location ?? 'Main Storage',
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return ListView(
            padding: EdgeInsets.all(rSize(context, 16)),
            children: [
              // Summary Header Case
              _buildMetricOverview(isWide),
              SizedBox(height: rSize(context, 20)),

              // Detailed Stats Grid
              _buildStatsGrid(isWide),
              SizedBox(height: rSize(context, 24)),

              // Quick Actions
              _buildQuickActions(isWide),
              SizedBox(height: rSize(context, 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricOverview(bool isWide) {
    return StreamBuilder<List<ProductDataWithStock>>(
      stream: database.inventoryDao.watchProductDatasWithStockByWarehouse(widget.warehouse.id),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        final totalStock = products.fold<int>(0, (sum, p) => sum + p.totalStock);
        final totalValue = products.fold<double>(0.0, (sum, p) => sum + (p.totalStock * (p.product.sellingPriceKobo / 100.0)));

        return Container(
          padding: EdgeInsets.all(rSize(context, 20)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [blueMain, blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: blueMain.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warehouse Value',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: rFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: rSize(context, 4)),
                    Text(
                      formatCurrency(totalValue),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: rFontSize(context, 28),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: rSize(context, 16), vertical: rSize(context, 8)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      totalStock.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Total Units',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(bool isWide) {
    return StreamBuilder<List<UserData>>(
      stream: database.warehousesDao.watchStaffByWarehouse(widget.warehouse.id),
      builder: (context, staffSnapshot) {
        final allStaff = staffSnapshot.data ?? [];
        final managers = allStaff.where((u) => u.roleTier >= 4).length;
        final riders = allStaff.where((u) => u.role.toLowerCase().contains('rider') || u.role.toLowerCase().contains('driver')).length;
        final regularStaff = allStaff.length - managers;

        return StreamBuilder<List<ProductDataWithStock>>(
          stream: database.inventoryDao.watchProductDatasWithStockByWarehouse(widget.warehouse.id),
          builder: (context, invSnapshot) {
            final activeProducts = (invSnapshot.data ?? []).where((p) => p.totalStock > 0).length;
            final lowStock = (invSnapshot.data ?? []).where((p) => p.totalStock > 0 && p.totalStock <= p.product.lowStockThreshold).length;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: rSize(context, 12),
              crossAxisSpacing: rSize(context, 12),
              childAspectRatio: 1.1,
              children: [
                _buildStatCard('Managers', managers.toString(), FontAwesomeIcons.userTie, const Color(0xFFA855F7)),
                _buildStatCard('Staff', regularStaff.toString(), FontAwesomeIcons.userGroup, blueMain),
                _buildStatCard('Riders', riders.toString(), FontAwesomeIcons.motorcycle, AppColors.warning),
                _buildStatCard('Products', activeProducts.toString(), FontAwesomeIcons.boxesStacked, AppColors.success),
                _buildStatCard('Low Stock', lowStock.toString(), FontAwesomeIcons.triangleExclamation, AppColors.danger),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(rSize(context, 16)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(rSize(context, 8)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: rSize(context, 16)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: rFontSize(context, 20),
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: rFontSize(context, 12),
                  color: _subtext,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: rFontSize(context, 16),
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        SizedBox(height: rSize(context, 12)),
        Row(
          children: [
            Expanded(
              child: _actionTile(
                'View Inventory',
                'Check and manage stock',
                FontAwesomeIcons.boxesStacked,
                blueMain,
                () {
                  navigationService.selectedWarehouseId.value = widget.warehouse.id.toString();
                  navigationService.setIndex(2); // Inventory
                },
              ),
            ),
            SizedBox(width: rSize(context, 12)),
            Expanded(
              child: _actionTile(
                'Manage Staff',
                'View assigned personnel',
                FontAwesomeIcons.usersGear,
                const Color(0xFFA855F7),
                () {
                  navigationService.setIndex(8); // Staff
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(rSize(context, 16)),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(rSize(context, 10)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: rSize(context, 18)),
            ),
            SizedBox(height: rSize(context, 12)),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: rFontSize(context, 14),
                color: _text,
              ),
            ),
            SizedBox(height: rSize(context, 2)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: rFontSize(context, 11),
                color: _subtext,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


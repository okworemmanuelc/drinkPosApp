import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/theme_settings_screen.dart';
import '../../core/utils/responsive.dart';
import '../../shared/services/navigation_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/user_tips_modal.dart';
import '../../core/database/app_database.dart';

class AppDrawer extends StatelessWidget {
  // Pass 'pos' or 'inventory' to highlight the correct nav item
  final String activeRoute;

  const AppDrawer({super.key, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Drawer(
      backgroundColor: t.colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildNavList(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(60),
        context.getRSize(20),
        context.getRSize(28),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            primary.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.getRSize(56),
            height: context.getRSize(56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SvgPicture.asset(
                'assets/images/logo.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: context.getRSize(16)),
          // Sync status indicator
          StreamBuilder<int>(
            stream: database.syncDao.watchPendingCount(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing $count file${count == 1 ? '' : 's'}…',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Text(
            authService.currentUser?.name ?? 'John Cashier',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: context.getRFontSize(18),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.getRSize(4)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(10),
              vertical: context.getRSize(4),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Terminal 01',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: context.getRFontSize(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavList(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(12),
        vertical: context.getRSize(16),
      ),
      children: [
        _navItem(
          context,
          FontAwesomeIcons.chartLine,
          'Dashboard',
          active: activeRoute == 'dashboard',
          onTap: () => _navigateTo(context, 'dashboard'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.cashRegister,
          'Point of Sale',
          active: activeRoute == 'pos',
          onTap: () => _navigateTo(context, 'pos'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.boxesStacked,
          'Inventory',
          active: activeRoute == 'inventory',
          onTap: () => _navigateTo(context, 'inventory'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.truckFast,
          'Orders',
          active: activeRoute == 'orders',
          onTap: () => _navigateTo(context, 'orders'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.users,
          'Customers',
          active: activeRoute == 'customers',
          onTap: () => _navigateTo(context, 'customers'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.moneyBillWave,
          'Supplier Accounts',
          active:
              activeRoute == 'supplier_accounts' || activeRoute == 'payments',
          onTap: () => _navigateTo(context, 'supplier_accounts'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.fileInvoiceDollar,
          'Expenses',
          active: activeRoute == 'expenses',
          onTap: () => _navigateTo(context, 'expenses'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.warehouse,
          'Warehouse',
          active: activeRoute == 'warehouse',
          onTap: () => _navigateTo(context, 'warehouse'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.userGroup,
          'Staff Management',
          active: activeRoute == 'staff',
          onTap: () => _navigateTo(context, 'staff'),
        ),
        SizedBox(height: context.getRSize(12)),
        Divider(color: t.dividerColor),
        SizedBox(height: context.getRSize(12)),
        _navItem(
          context,
          FontAwesomeIcons.clockRotateLeft,
          'Activity Logs',
          active: activeRoute == 'activity_logs',
          onTap: () => _navigateTo(context, 'activity_logs'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.truckArrowRight,
          'Deliveries',
          active: activeRoute == 'deliveries',
          onTap: () => _navigateTo(context, 'deliveries'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.cartShopping,
          'Cart',
          active: activeRoute == 'cart',
          onTap: () => _navigateTo(context, 'cart'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.lightbulb,
          'Pro Tips',
          active: false,
          onTap: () {
            Navigator.pop(context);
            UserTipsModal.show(context);
          },
        ),
        SizedBox(height: context.getRSize(12)),
        Divider(color: t.dividerColor),
        SizedBox(height: context.getRSize(12)),
        _navItem(
          context,
          FontAwesomeIcons.rightFromBracket,
          'Log Out',
          active: false,
          outlined: true,
          iconColor: t.colorScheme.error,
          labelColor: t.colorScheme.error,
          onTap: () {
            Navigator.pop(context); // close the drawer first
            authService.logout();   // clears the user → main.dart shows login screen
          },
        ),
        SizedBox(height: context.getRSize(12)),
        Divider(color: t.dividerColor),
        SizedBox(height: context.getRSize(12)),
        _buildAppearanceTile(context),
        // Extra space for system navigation bar
        SizedBox(height: MediaQuery.of(context).padding.bottom + context.getRSize(20)),
      ],
    );
  }

  // ── Navigation logic — now uses NavigationService shell ────────────────────
  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context);

    if (route == 'dashboard') {
      navigationService.setIndex(0);
    } else if (route == 'pos') {
      navigationService.setIndex(1);
    } else if (route == 'inventory') {
      navigationService.setIndex(2);
    } else if (route == 'orders') {
      navigationService.setIndex(3);
    } else if (route == 'customers') {
      navigationService.setIndex(4);
    } else if (route == 'supplier_accounts' || route == 'payments') {
      navigationService.setIndex(5);
    } else if (route == 'expenses') {
      navigationService.setIndex(6);
    } else if (route == 'warehouse') {
      navigationService.setIndex(7);
    } else if (route == 'staff') {
      navigationService.setIndex(8);
    } else if (route == 'cart') {
      navigationService.setIndex(9);
    } else if (route == 'deliveries') {
      navigationService.setIndex(10);
    } else if (route == 'activity_logs') {
      navigationService.setIndex(11);
    }
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label, {
    bool active = false,
    bool outlined = false,
    VoidCallback? onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    final cardColor = t.cardColor;
    final subtextColor = t.textTheme.bodySmall?.color ?? t.iconTheme.color!;
    final textColor = t.colorScheme.onSurface;

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(6)),
      decoration: outlined
          ? BoxDecoration(
              border: Border.all(color: t.colorScheme.error.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: Material(
        color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () {},
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(16),
              vertical: context.getRSize(12),
            ),
            child: Row(
              children: [
                Container(
                  width: context.getRSize(36),
                  height: context.getRSize(36),
                  decoration: BoxDecoration(
                    color: active ? primary.withValues(alpha: 0.2) : cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: context.getRSize(16),
                    color: iconColor ?? (active ? primary : subtextColor),
                  ),
                ),
                SizedBox(width: context.getRSize(14)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      fontSize: context.getRFontSize(14.5),
                      color: labelColor ?? (active ? primary : textColor),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active) ...[
                  SizedBox(width: context.getRSize(8)),
                  Container(
                    width: context.getRSize(6),
                    height: context.getRSize(6),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Appearance tile that navigates to the full Theme Settings screen.
  Widget _buildAppearanceTile(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.getRSize(16),
        vertical: context.getRSize(12),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context); // close drawer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ThemeSettingsScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(14),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: context.getRSize(32),
                height: context.getRSize(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    FontAwesomeIcons.palette,
                    size: context.getRSize(14),
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: context.getRSize(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(14),
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Theme & Display',
                      style: TextStyle(
                        fontSize: context.getRFontSize(11),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FontAwesomeIcons.chevronRight,
                size: context.getRSize(14),
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Navigation Registration (Now Legacy/Optional) ───────────────────────────
// These were used to break circular imports before the MainLayout shell refactor.
// Current MainLayout directly imports screens, but keeping definitions for reference 
// or until all feature-to-drawer links are fully migrated to NvigationService.


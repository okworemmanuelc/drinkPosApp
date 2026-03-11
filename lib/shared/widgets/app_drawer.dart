import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/utils/responsive.dart';
import '../../shared/services/navigation_service.dart';

class AppDrawer extends StatelessWidget {
  // Pass 'pos' or 'inventory' to highlight the correct nav item
  final String activeRoute;

  const AppDrawer({super.key, required this.activeRoute});

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _cardCol => _isDark ? dCard : lCard;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => Drawer(
        backgroundColor: _surface,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildNavList(context)),
            SafeArea(top: false, child: _buildLogout(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.getRSize(20),
        context.getRSize(60),
        context.getRSize(20),
        context.getRSize(28),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(context.getRSize(12)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(
              FontAwesomeIcons.user,
              color: Colors.white,
              size: context.getRSize(26), // Responsive icon
            ),
          ),
          SizedBox(height: context.getRSize(16)),
          Text(
            'John Cashier',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.getRFontSize(18), // Responsive font
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
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Terminal 01',
              style: TextStyle(
                color: Colors.white,
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
          'Manage Warehouse',
          active: activeRoute == 'warehouse',
          onTap: () => _navigateTo(context, 'warehouse'),
        ),
        _navItem(
          context,
          FontAwesomeIcons.userGroup,
          'Staff',
          active: activeRoute == 'staff',
          onTap: () => _navigateTo(context, 'staff'),
        ),
        SizedBox(height: context.getRSize(12)),
        Divider(color: _border),
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
        SizedBox(height: context.getRSize(12)),
        Divider(color: _border),
        SizedBox(height: context.getRSize(12)),
        _buildThemeToggle(context),
      ],
    );
  }

  // ── Navigation logic — now uses NavigationService shell ────────────────────
  void _navigateTo(BuildContext context, String route) {
    // Always close the drawer first
    Navigator.pop(context);

    // Ensure we are at the root MainLayout shell
    Navigator.of(context).popUntil((r) => r.isFirst);

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
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(6)),
      child: Material(
        color: active ? blueMain.withOpacity(0.1) : Colors.transparent,
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
                    color: active ? blueMain.withOpacity(0.2) : _cardCol,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: context.getRSize(16),
                    color: active ? blueMain : _subtext,
                  ),
                ),
                SizedBox(width: context.getRSize(14)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      fontSize: context.getRFontSize(14.5),
                      color: active ? blueMain : _text,
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
                    decoration: const BoxDecoration(
                      color: blueMain,
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

  Widget _buildThemeToggle(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        final isSystem = mode == ThemeMode.system;
        final dark = mode == ThemeMode.dark;
        final label = isSystem
            ? 'System Theme'
            : dark
            ? 'Dark Theme'
            : 'Light Theme';
        final icon = isSystem
            ? FontAwesomeIcons.desktop
            : dark
            ? FontAwesomeIcons.moon
            : FontAwesomeIcons.sun;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<ThemeMode>(
              initialValue: mode,
              tooltip: 'Select Theme',
              offset: Offset(0, context.getRSize(-160)), // roll to the upside
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: _surface,
              elevation: 8,
              onSelected: (ThemeMode newMode) {
                themeNotifier.value = newMode;
              },
              itemBuilder: (context) => [
                _buildThemeMenuItem(
                  context,
                  ThemeMode.light,
                  'Light Theme',
                  FontAwesomeIcons.sun,
                  mode,
                ),
                _buildThemeMenuItem(
                  context,
                  ThemeMode.dark,
                  'Dark Theme',
                  FontAwesomeIcons.moon,
                  mode,
                ),
                _buildThemeMenuItem(
                  context,
                  ThemeMode.system,
                  'System Theme',
                  FontAwesomeIcons.desktop,
                  mode,
                ),
              ],
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: context.getRSize(16),
                  vertical: context.getRSize(14),
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blueMain, blueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: blueMain.withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: context.getRSize(14),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: context.getRSize(14)),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.getRFontSize(14.5),
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      FontAwesomeIcons.chevronUp,
                      size: context.getRSize(14),
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<ThemeMode> _buildThemeMenuItem(
    BuildContext context,
    ThemeMode value,
    String text,
    IconData icon,
    ThemeMode currentMode,
  ) {
    final isActive = value == currentMode;
    return PopupMenuItem<ThemeMode>(
      value: value,
      child: SizedBox(
        width: context.getRSize(180),
        child: Row(
          children: [
            Icon(
              icon,
              size: context.getRSize(16),
              color: isActive ? blueMain : _text,
            ),
            SizedBox(width: context.getRSize(12)),
            Text(
              text,
              style: TextStyle(
                color: isActive ? blueMain : _text,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: context.getRFontSize(14),
              ),
            ),
            const Spacer(),
            if (isActive)
              Icon(
                FontAwesomeIcons.circleCheck,
                size: context.getRSize(16),
                color: blueMain,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.getRSize(16)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.getRSize(14)),
        decoration: BoxDecoration(
          color: danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: danger.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.rightFromBracket,
              color: danger,
              size: context.getRSize(16),
            ),
            SizedBox(width: context.getRSize(10)),
            Text(
              'Logout',
              style: TextStyle(
                color: danger,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(14),
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


// ── Navigation Registration (Now Legacy/Optional) ───────────────────────────
// These were used to break circular imports before the MainLayout shell refactor.
// Current MainLayout directly imports screens, but keeping definitions for reference 
// or until all feature-to-drawer links are fully migrated to NvigationService.

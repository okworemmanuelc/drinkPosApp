import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/utils/responsive.dart';
import '../../shared/services/navigation_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/user_tips_modal.dart';
import '../../core/database/app_database.dart';

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
            width: context.getRSize(56),
            height: context.getRSize(56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/ribaplus_logo.png',
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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing $count file${count == 1 ? '' : 's'}…',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
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
              color: Colors.white.withValues(alpha: 0.15),
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
        Divider(color: _border),
        SizedBox(height: context.getRSize(12)),
        _navItem(
          context,
          FontAwesomeIcons.rightFromBracket,
          'Log Out',
          active: false,
          outlined: true,
          iconColor: danger,
          labelColor: danger,
          onTap: () {
            Navigator.pop(context); // close the drawer first
            authService.logout();   // clears the user → main.dart shows login screen
          },
        ),
        SizedBox(height: context.getRSize(12)),
        Divider(color: _border),
        SizedBox(height: context.getRSize(12)),
        _buildThemeToggle(context),
        // Extra space for system navigation bar
        SizedBox(height: MediaQuery.of(context).padding.bottom + context.getRSize(20)),
      ],
    );
  }

  // ── Navigation logic — now uses NavigationService shell ────────────────────
  void _navigateTo(BuildContext context, String route) {
    // Close the drawer only — MainLayout uses IndexedStack so no Navigator
    // stack manipulation is needed. popUntil was previously popping all the
    // way back to OnboardingScreen, causing a spurious "logout".
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
    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(6)),
      decoration: outlined
          ? BoxDecoration(
              border: Border.all(color: danger.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: Material(
        color: active ? blueMain.withValues(alpha: 0.1) : Colors.transparent,
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
                    color: active ? blueMain.withValues(alpha: 0.2) : _cardCol,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: context.getRSize(16),
                    color: iconColor ?? (active ? blueMain : _subtext),
                  ),
                ),
                SizedBox(width: context.getRSize(14)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      fontSize: context.getRFontSize(14.5),
                      color: labelColor ?? (active ? blueMain : _text),
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
                      color: blueMain.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.8),
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

}


// ── Navigation Registration (Now Legacy/Optional) ───────────────────────────
// These were used to break circular imports before the MainLayout shell refactor.
// Current MainLayout directly imports screens, but keeping definitions for reference 
// or until all feature-to-drawer links are fully migrated to NvigationService.


import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';

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
            _buildHeader(),
            Expanded(child: _buildNavList(context)),
            _buildLogout(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              FontAwesomeIcons.user,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'John Cashier',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Terminal 01',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
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
        _navItem(context, FontAwesomeIcons.truckFast, 'Deliveries'),
        _navItem(context, FontAwesomeIcons.users, 'Customers'),
        const SizedBox(height: 12),
        Divider(color: _border),
        const SizedBox(height: 12),
        _buildThemeToggle(),
      ],
    );
  }

  // ── Navigation logic — all routing lives here ──────────────────────────────
  void _navigateTo(BuildContext context, String route) {
    // Always close the drawer first
    Navigator.pop(context);

    if (route == activeRoute) return; // already here

    if (route == 'pos') {
      // Pop back to POS (it's always the root)
      Navigator.of(context).popUntil((r) => r.isFirst);
    }

    if (route == 'inventory') {
      // Import lazily to avoid circular dep — see note below
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const _InventoryScreenProxy()));
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
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? blueMain.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? blueMain.withValues(alpha: 0.2) : _cardCol,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: active ? blueMain : _subtext,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14.5,
                    color: active ? blueMain : _text,
                  ),
                ),
                if (active) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
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

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        final dark = mode == ThemeMode.dark;
        return GestureDetector(
          onTap: () =>
              themeNotifier.value = dark ? ThemeMode.light : ThemeMode.dark,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    dark ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
                    size: 16,
                    color: blueMain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: _text,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: dark ? blueMain : _border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: dark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: danger.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(FontAwesomeIcons.rightFromBracket, color: danger, size: 16),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                color: danger,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Proxy widget to break circular import ────────────────────────────────────
// AppDrawer can't import InventoryScreen directly (InventoryScreen imports
// AppDrawer), so we use a thin proxy that imports it at build time.
class _InventoryScreenProxy extends StatelessWidget {
  const _InventoryScreenProxy();

  @override
  Widget build(BuildContext context) {
    // The import is deferred to runtime via the builder — no circular dep.
    // We import InventoryScreen here inside the features layer at call time.
    return const _InventoryLoader();
  }
}

// This widget lives in app_drawer.dart but the actual InventoryScreen
// is imported at the BOTTOM of this file to keep the reference one-directional.
class _InventoryLoader extends StatelessWidget {
  const _InventoryLoader();

  @override
  Widget build(BuildContext context) {
    return _inventoryScreenBuilder();
  }
}

// Override this function in main.dart after all screens exist.
// Default: shows a placeholder until you wire it up in Step 18.
Widget Function() _inventoryScreenBuilder = () => const Scaffold(
  body: Center(child: Text('Inventory screen not registered yet')),
);

/// Call this once from main.dart to register the real InventoryScreen.
/// Example:  registerInventoryScreen(() => const InventoryScreen());
void registerInventoryScreen(Widget Function() builder) {
  _inventoryScreenBuilder = builder;
}

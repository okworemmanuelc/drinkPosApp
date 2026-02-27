import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const BrewFlowApp());
}

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
// Light Theme (Slate & White)
const Color _lBg = Color(0xFFF8FAFC); // slate-50
const Color _lSurface = Color(0xFFFFFFFF);
const Color _lCard = Color(0xFFF1F5F9); // slate-100
const Color _lText = Color(0xFF0F172A); // slate-900
const Color _lSubtext = Color(0xFF64748B); // slate-500
const Color _lBorder = Color(0xFFE2E8F0); // slate-200

// Dark Theme (Deep Blue-Grey)
const Color _dBg = Color(0xFF0F172A); // slate-900
const Color _dSurface = Color(0xFF1E293B); // slate-800
const Color _dCard = Color(0xFF334155); // slate-700
const Color _dText = Color(0xFFF8FAFC); // slate-50
const Color _dSubtext = Color(0xFF94A3B8); // slate-400
const Color _dBorder = Color(0xFF475569); // slate-600

// Shared Accents (Modern Blue Palette)
const Color blueMain = Color(0xFF2563EB); // blue-600
const Color blueLight = Color(0xFF60A5FA); // blue-400
const Color blueDark = Color(0xFF1D4ED8); // blue-700
const Color danger = Color(0xFFEF4444); // red-500
const Color success = Color(0xFF10B981); // emerald-500

// ─── CRATE GROUP ENUM ─────────────────────────────────────────────────────────
enum CrateGroup { nbPlc, guinness, cocaCola, premium }

extension CrateGroupLabel on CrateGroup {
  String get label {
    switch (this) {
      case CrateGroup.nbPlc:
        return 'NB Plc';
      case CrateGroup.guinness:
        return 'Guinness';
      case CrateGroup.cocaCola:
        return 'Coca-Cola';
      case CrateGroup.premium:
        return 'Premium';
    }
  }

  Color get color {
    switch (this) {
      case CrateGroup.nbPlc:
        return const Color(0xFFF59E0B);
      case CrateGroup.guinness:
        return const Color(0xFF334155);
      case CrateGroup.cocaCola:
        return const Color(0xFFEF4444);
      case CrateGroup.premium:
        return const Color(0xFF8B5CF6);
    }
  }
}

// ─── SUPPLIER MODEL ───────────────────────────────────────────────────────────
class Supplier {
  final String id;
  String name;
  CrateGroup crateGroup;
  bool trackInventory;

  Supplier({
    required this.id,
    required this.name,
    required this.crateGroup,
    this.trackInventory = true,
  });
}

// ─── INVENTORY ITEM MODEL ─────────────────────────────────────────────────────
class InventoryItem {
  final String id;
  String productName;
  String subtitle;
  String supplierId;
  IconData icon;
  Color color;
  double stock;
  double lowStockThreshold;

  InventoryItem({
    required this.id,
    required this.productName,
    required this.subtitle,
    required this.supplierId,
    required this.icon,
    required this.color,
    this.stock = 0,
    this.lowStockThreshold = 5,
  });
}

// ─── CRATE STOCK MODEL ────────────────────────────────────────────────────────
class CrateStock {
  CrateGroup group;
  double available;

  CrateStock({required this.group, this.available = 0});
}

// ─── INVENTORY LOG MODEL ──────────────────────────────────────────────────────
class InventoryLog {
  final DateTime timestamp;
  final String user;
  final String itemId;
  final String itemName;
  final String
  action; // 'restock', 'adjustment', 'crate_update', 'new_supplier'
  final double previousValue;
  final double newValue;
  final String? note;

  InventoryLog({
    required this.timestamp,
    required this.user,
    required this.itemId,
    required this.itemName,
    required this.action,
    required this.previousValue,
    required this.newValue,
    this.note,
  });
}

// ─── INVENTORY STATE ──────────────────────────────────────────────────────────
final List<Supplier> kSuppliers = [
  Supplier(
    id: 's1',
    name: 'Nigerian Breweries Plc',
    crateGroup: CrateGroup.nbPlc,
  ),
  Supplier(id: 's2', name: 'Guinness Nigeria', crateGroup: CrateGroup.guinness),
  Supplier(
    id: 's3',
    name: 'Coca-Cola Nigeria',
    crateGroup: CrateGroup.cocaCola,
  ),
];

final List<CrateStock> kCrateStocks = [
  CrateStock(group: CrateGroup.nbPlc, available: 24),
  CrateStock(group: CrateGroup.guinness, available: 12),
  CrateStock(group: CrateGroup.cocaCola, available: 8),
  CrateStock(group: CrateGroup.premium, available: 0),
];

final List<InventoryItem> kInventoryItems = [
  InventoryItem(
    id: 'i1',
    productName: 'Star Lager',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: const Color(0xFFF59E0B),
    stock: 18,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i2',
    productName: 'Heineken',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: const Color(0xFF10B981),
    stock: 42,
    lowStockThreshold: 10,
  ),
  InventoryItem(
    id: 'i3',
    productName: 'Guinness',
    subtitle: 'Stout',
    supplierId: 's2',
    icon: FontAwesomeIcons.wineGlassEmpty,
    color: const Color(0xFF334155),
    stock: 6,
    lowStockThreshold: 8,
  ),
  InventoryItem(
    id: 'i4',
    productName: 'Goldberg',
    subtitle: 'Keg',
    supplierId: 's1',
    icon: FontAwesomeIcons.database,
    color: const Color(0xFFD97706),
    stock: 3,
    lowStockThreshold: 4,
  ),
  InventoryItem(
    id: 'i5',
    productName: 'Tiger Beer',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: const Color(0xFF3B82F6),
    stock: 30,
    lowStockThreshold: 10,
  ),
  InventoryItem(
    id: 'i6',
    productName: '33 Export',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: const Color(0xFFEA580C),
    stock: 2,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i7',
    productName: 'Desperados',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: const Color(0xFFE11D48),
    stock: 14,
    lowStockThreshold: 6,
  ),
  InventoryItem(
    id: 'i8',
    productName: 'Legend Stout',
    subtitle: 'Keg',
    supplierId: 's2',
    icon: FontAwesomeIcons.database,
    color: const Color(0xFF475569),
    stock: 1,
    lowStockThreshold: 3,
  ),
  InventoryItem(
    id: 'i9',
    productName: 'Life Lager',
    subtitle: 'Crate',
    supplierId: 's1',
    icon: FontAwesomeIcons.beerMugEmpty,
    color: const Color(0xFFEAB308),
    stock: 9,
    lowStockThreshold: 5,
  ),
  InventoryItem(
    id: 'i10',
    productName: 'Maltina',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: const Color(0xFF78350F),
    stock: 22,
    lowStockThreshold: 8,
  ),
  InventoryItem(
    id: 'i11',
    productName: 'Amstel Malta',
    subtitle: 'Can',
    supplierId: 's1',
    icon: FontAwesomeIcons.wineBottle,
    color: const Color(0xFFC2410C),
    stock: 17,
    lowStockThreshold: 8,
  ),
];

final List<InventoryLog> kInventoryLogs = [];

// ─── THEME NOTIFIER ───────────────────────────────────────────────────────────
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// ─── APP ROOT ─────────────────────────────────────────────────────────────────
class BrewFlowApp extends StatelessWidget {
  const BrewFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'BrewFlow POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _buildLight(),
        darkTheme: _buildDark(),
        home: const PosHomeScreen(),
      ),
    );
  }

  ThemeData _buildLight() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.light(
      primary: blueMain,
      secondary: blueLight,
      surface: _lSurface,
      onSurface: _lText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lSurface,
      foregroundColor: _lText,
      elevation: 0,
      centerTitle: false,
    ),
    cardColor: _lSurface,
    dividerColor: _lBorder,
    chipTheme: ChipThemeData(
      backgroundColor: _lCard,
      selectedColor: _lText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'sans-serif',
        color: _lText,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: _lText),
      bodySmall: TextStyle(color: _lSubtext),
    ),
  );

  ThemeData _buildDark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _dBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.dark(
      primary: blueMain,
      secondary: blueLight,
      surface: _dSurface,
      onSurface: _dText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _dSurface,
      foregroundColor: _dText,
      elevation: 0,
      centerTitle: false,
    ),
    cardColor: _dCard,
    dividerColor: _dBorder,
    chipTheme: ChipThemeData(
      backgroundColor: _dCard,
      selectedColor: blueMain,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'sans-serif',
        color: _dText,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: _dText),
      bodySmall: TextStyle(color: _dSubtext),
    ),
  );
}

// ─── PRODUCT DATA ─────────────────────────────────────────────────────────────
final List<Map<String, dynamic>> kProducts = [
  {
    'name': 'Star Lager',
    'subtitle': 'Crate',
    'price': 5000,
    'wholesale_price': 4500,
    'category': 'Glass Crates',
    'icon': FontAwesomeIcons.beerMugEmpty,
    'color': const Color(0xFFF59E0B), // Amber
  },
  {
    'name': 'Heineken',
    'subtitle': 'Can',
    'price': 8500,
    'wholesale_price': 8000,
    'category': 'Cans & PET',
    'icon': FontAwesomeIcons.wineBottle,
    'color': const Color(0xFF10B981), // Emerald
  },
  {
    'name': 'Guinness',
    'subtitle': 'Stout',
    'price': 7200,
    'wholesale_price': 6800,
    'category': 'Glass Crates',
    'icon': FontAwesomeIcons.wineGlassEmpty,
    'color': const Color(0xFF334155), // Slate dark
  },
  {
    'name': 'Goldberg',
    'subtitle': 'Keg',
    'price': 15000,
    'wholesale_price': 14000,
    'category': 'Kegs',
    'icon': FontAwesomeIcons.database,
    'color': const Color(0xFFD97706), // Amber dark
  },
  {
    'name': 'Tiger Beer',
    'subtitle': 'Can',
    'price': 8000,
    'wholesale_price': 7600,
    'category': 'Cans & PET',
    'icon': FontAwesomeIcons.wineBottle,
    'color': const Color(0xFF3B82F6), // Blue
  },
  {
    'name': '33 Export',
    'subtitle': 'Crate',
    'price': 4800,
    'wholesale_price': 4400,
    'category': 'Glass Crates',
    'icon': FontAwesomeIcons.beerMugEmpty,
    'color': const Color(0xFFEA580C), // Orange
  },
  {
    'name': 'Desperados',
    'subtitle': 'Can',
    'price': 9000,
    'wholesale_price': 8500,
    'category': 'Cans & PET',
    'icon': FontAwesomeIcons.wineBottle,
    'color': const Color(0xFFE11D48), // Rose
  },
  {
    'name': 'Legend Stout',
    'subtitle': 'Keg',
    'price': 16000,
    'wholesale_price': 15200,
    'category': 'Kegs',
    'icon': FontAwesomeIcons.database,
    'color': const Color(0xFF475569), // Slate
  },
  {
    'name': 'Life Lager',
    'subtitle': 'Crate',
    'price': 4900,
    'wholesale_price': 4500,
    'category': 'Glass Crates',
    'icon': FontAwesomeIcons.beerMugEmpty,
    'color': const Color(0xFFEAB308), // Yellow
  },
  {
    'name': 'Maltina',
    'subtitle': 'Can',
    'price': 5000,
    'wholesale_price': 4600,
    'category': 'Cans & PET',
    'icon': FontAwesomeIcons.wineBottle,
    'color': const Color(0xFF78350F), // Amber darkest
  },
  {
    'name': 'Amstel Malta',
    'subtitle': 'Can',
    'price': 5500,
    'wholesale_price': 5100,
    'category': 'Cans & PET',
    'icon': FontAwesomeIcons.wineBottle,
    'color': const Color(0xFFC2410C), // Orange dark
  },
];

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────
class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});
  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen>
    with TickerProviderStateMixin {
  String _filter = 'All';
  bool _isWholesale = false;
  final double _customerBalance = -1500.00;
  late AnimationController _fabAnim;

  final List<Map<String, dynamic>> _cart = [
    {
      'name': 'Star Lager',
      'subtitle': 'Crate',
      'price': 5000,
      'qty': 1.0,
      'icon': FontAwesomeIcons.beerMugEmpty,
      'color': const Color(0xFFF59E0B),
    },
    {
      'name': 'Heineken',
      'subtitle': 'Can',
      'price': 8500,
      'qty': 2.5,
      'icon': FontAwesomeIcons.wineBottle,
      'color': const Color(0xFF10B981),
    },
  ];

  final List<String> _filters = ['All', 'Glass Crates', 'Cans & PET', 'Kegs'];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnim.forward();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  bool get _isDark => themeNotifier.value == ThemeMode.dark;

  Color get _bg => _isDark ? _dBg : _lBg;
  Color get _surface => _isDark ? _dSurface : _lSurface;
  Color get _cardBg => _isDark ? _dCard : _lSurface;
  Color get _text => _isDark ? _dText : _lText;
  Color get _subtext => _isDark ? _dSubtext : _lSubtext;
  Color get _border => _isDark ? _dBorder : _lBorder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(child: _buildGrid()),
          ],
        ),
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // ── APP BAR ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 16,
                  decoration: BoxDecoration(
                    color: blueMain,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blueLight, blueMain]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.beerMugEmpty,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BrewFlow',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Point of Sale',
                style: TextStyle(
                  fontSize: 11,
                  color: blueMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _iconBtn(FontAwesomeIcons.magnifyingGlass, () {}, size: 17),
        Stack(
          alignment: Alignment.center,
          children: [
            _iconBtn(
              FontAwesomeIcons.cartShopping,
              () => _openCart(),
              size: 17,
            ),
            if (_cart.isNotEmpty)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 2),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {double size = 18}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: size, color: _subtext),
      ),
    );
  }

  // ── HEADER STRIP ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          // Quick Sale Button
          GestureDetector(
            onTap: () {
              /* TODO: Quick Sale */
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: blueMain.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blueMain.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.bolt, size: 14, color: blueMain),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Sale',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isDark ? blueLight : blueDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Price toggle pill
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pricePill('Retail', !_isWholesale),
                const SizedBox(width: 4),
                _pricePill('Wholesale', _isWholesale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isWholesale = label == 'Wholesale'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? blueMain : _subtext,
          ),
        ),
      ),
    );
  }

  // ── FILTER BAR ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Divider(height: 1, color: _border),
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final active = _filter == _filters[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = _filters[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active ? blueMain : (_isDark ? _dCard : _lCard),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? blueMain : _border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _filters[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: active ? Colors.white : _subtext,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── PRODUCT GRID ────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    final shown = _filter == 'All'
        ? kProducts
        : kProducts.where((p) => p['category'] == _filter).toList();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.80,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: shown.length,
      itemBuilder: (_, i) => _buildProductCard(shown[i]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final price = _isWholesale
        ? (product['wholesale_price'] ?? product['price'])
        : product['price'];
    final cartIdx = _cart.indexWhere((c) => c['name'] == product['name']);
    final inCart = cartIdx != -1;
    final qty = inCart ? _cart[cartIdx]['qty'] : 0.0;
    final Color accent = product['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (inCart) {
            _cart[cartIdx]['qty'] += 1.0;
          } else {
            _cart.add({
              'name': product['name'],
              'subtitle': product['subtitle'],
              'price': price,
              'qty': 1.0,
              'icon': product['icon'],
              'color': product['color'],
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? blueMain : _border,
            width: inCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: inCart
                  ? blueMain.withOpacity(0.15)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        product['icon'] as IconData,
                        size: 28,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product['subtitle'],
                    style: TextStyle(fontSize: 10, color: _subtext),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isDark ? _dBg : _lBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₦${_fmt(price)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _isDark ? blueLight : blueDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: blueMain,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    qty.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 14, color: _subtext),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    final total = _cart.fold<double>(0, (s, i) => s + (i['price'] * i['qty']));
    return ScaleTransition(
      scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
      child: GestureDetector(
        onTap: _openCart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [blueLight, blueMain],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: blueMain.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                FontAwesomeIcons.cartShopping,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'View Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (_cart.isNotEmpty)
                    Text(
                      '₦${_fmt(total.toInt())}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (_cart.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_cart.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── DRAWER ──────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _surface,
      child: Column(
        children: [
          // Header
          Container(
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.userLarge,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
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
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _drawerItem(
                  FontAwesomeIcons.cashRegister,
                  'Point of Sale',
                  active: true,
                ),
                _drawerItem(
                  FontAwesomeIcons.boxesStacked,
                  'Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(FontAwesomeIcons.truckFast, 'Deliveries'),
                _drawerItem(FontAwesomeIcons.users, 'Customers'),
                const SizedBox(height: 12),
                Divider(color: _border),
                const SizedBox(height: 12),
                // Dark mode toggle
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (_, mode, __) {
                    final dark = mode == ThemeMode.dark;
                    return GestureDetector(
                      onTap: () => themeNotifier.value = dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                                dark
                                    ? FontAwesomeIcons.moon
                                    : FontAwesomeIcons.sun,
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: danger.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      FontAwesomeIcons.rightFromBracket,
                      color: danger,
                      size: 16,
                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? blueMain.withOpacity(0.1) : Colors.transparent,
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
                    color: active
                        ? blueMain.withOpacity(0.2)
                        : (_isDark ? _dCard : _lCard),
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

  // ── CART MODAL ──────────────────────────────────────────────────────────────
  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          _cart.sort((a, b) => b['qty'].compareTo(a['qty']));
          final sub = _cart.fold<double>(
            0,
            (s, i) => s + (i['price'] * i['qty']),
          );
          const dep = 1500.0;
          final tot = sub + dep;
          final bg = _isDark ? _dSurface : _lSurface;
          final card = _isDark ? _dCard : _lCard;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Cart',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          Text(
                            '${_cart.length} item${_cart.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: blueMain,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_cart.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setModal(() => _cart.clear());
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: danger.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  FontAwesomeIcons.trashCan,
                                  color: danger,
                                  size: 13,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.close, color: _subtext, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: blueMain.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.userTag,
                            size: 16,
                            color: blueMain,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Walk-in Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.nairaSign,
                                  size: 11,
                                  color: _customerBalance < 0
                                      ? danger
                                      : success,
                                ),
                                Text(
                                  ' Bal: ₦${_customerBalance.abs().toStringAsFixed(0)} ${_customerBalance < 0 ? "overdue" : "credit"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _customerBalance < 0
                                        ? danger
                                        : success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _subtext,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: _border),
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.cartArrowDown,
                                size: 48,
                                color: _border,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cart is empty',
                                style: TextStyle(
                                  color: _subtext,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = _cart[i];
                            final Color c = item['color'] as Color;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: c.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      color: c,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: _text,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['qty'].toStringAsFixed(1)} × ₦${_fmt(item['price'])}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _subtext,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₦${_fmt((item['price'] * item['qty']).toInt())}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: _text,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () =>
                                            _editItem(ctx, item, setModal),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: blueMain.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Edit',
                                            style: TextStyle(
                                              color: blueMain,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Column(
                    children: [
                      _totalRow('Subtotal', sub, small: true),
                      const SizedBox(height: 8),
                      _totalRow('Crate Deposit', dep, small: true),
                      const SizedBox(height: 16),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 16),
                      _totalRow('Total', tot, large: true),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blueLight, blueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: blueMain.withOpacity(0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                FontAwesomeIcons.checkToSlot,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool small = false,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: large ? FontWeight.bold : FontWeight.w600,
            color: large ? _text : _subtext,
          ),
        ),
        Text(
          '₦${_fmt(value.toInt())}',
          style: TextStyle(
            fontSize: large ? 22 : 15,
            fontWeight: FontWeight.w800,
            color: large ? blueMain : _text,
          ),
        ),
      ],
    );
  }

  // ── EDIT DIALOG ─────────────────────────────────────────────────────────────
  void _editItem(
    BuildContext ctx,
    Map<String, dynamic> item,
    StateSetter setModal,
  ) {
    final qtyCtrl = TextEditingController(text: item['qty'].toString());
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          backgroundColor: _isDark ? _dSurface : _lSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Quantity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['name'],
                style: TextStyle(
                  fontSize: 13,
                  color: blueMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Row(
            children: [
              _qtyBtn(FontAwesomeIcons.minus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                if (v > 0.5)
                  setD(() => qtyCtrl.text = (v - 0.5).toStringAsFixed(1));
              }),
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              _qtyBtn(FontAwesomeIcons.plus, () {
                final v = double.tryParse(qtyCtrl.text) ?? 1.0;
                setD(() => qtyCtrl.text = (v + 0.5).toStringAsFixed(1));
              }),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton.icon(
              onPressed: () {
                setModal(() => _cart.remove(item));
                setState(() {});
                Navigator.pop(dCtx);
              },
              icon: const Icon(FontAwesomeIcons.trash, color: danger, size: 15),
              label: const Text(
                'Remove',
                style: TextStyle(color: danger, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              onPressed: () {
                setModal(
                  () => item['qty'] = double.tryParse(qtyCtrl.text) ?? 1.0,
                );
                setState(() {});
                Navigator.pop(dCtx);
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: blueMain.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: blueMain.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: blueMain),
      ),
    );
  }

  // ── UTILS ────────────────────────────────────────────────────────────────────
  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      final offset = s.length % 3;
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (i - offset) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return n.toString();
  }
}

// ─── INVENTORY SCREEN ─────────────────────────────────────────────────────────
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSupplierId = 'all';

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? _dBg : _lBg;
  Color get _surface => _isDark ? _dSurface : _lSurface;
  Color get _cardBg => _isDark ? _dCard : _lSurface;
  Color get _text => _isDark ? _dText : _lText;
  Color get _subtext => _isDark ? _dSubtext : _lSubtext;
  Color get _border => _isDark ? _dBorder : _lBorder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            _buildSummaryCards(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsTab(),
                  _buildCratesTab(),
                  _buildLogTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildAddFab(),
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 16,
                  decoration: BoxDecoration(
                    color: blueMain,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 2.5,
                  width: 22,
                  decoration: BoxDecoration(
                    color: _text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blueLight, blueMain]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: blueMain.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.boxesStacked,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Stock Management',
                style: TextStyle(
                  fontSize: 11,
                  color: blueMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showAddSupplierDialog,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: blueMain.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: blueMain.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.buildingColumns,
                  size: 13,
                  color: blueMain,
                ),
                const SizedBox(width: 6),
                Text(
                  '+ Supplier',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isDark ? blueLight : blueDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── DRAWER (mirrors POS drawer with Inventory active) ───────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _surface,
      child: Column(
        children: [
          Container(
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.userLarge,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
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
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _navItem(
                  FontAwesomeIcons.cashRegister,
                  'Point of Sale',
                  active: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
                _navItem(
                  FontAwesomeIcons.boxesStacked,
                  'Inventory',
                  active: true,
                ),
                _navItem(FontAwesomeIcons.truckFast, 'Deliveries'),
                _navItem(FontAwesomeIcons.users, 'Customers'),
                const SizedBox(height: 12),
                Divider(color: _border),
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (_, mode, __) {
                    final dark = mode == ThemeMode.dark;
                    return GestureDetector(
                      onTap: () => themeNotifier.value = dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                                dark
                                    ? FontAwesomeIcons.moon
                                    : FontAwesomeIcons.sun,
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: danger.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    FontAwesomeIcons.rightFromBracket,
                    color: danger,
                    size: 16,
                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? blueMain.withOpacity(0.1) : Colors.transparent,
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
                    color: active
                        ? blueMain.withOpacity(0.2)
                        : (_isDark ? _dCard : _lCard),
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

  // ── SUMMARY CARDS ────────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final totalItems = kInventoryItems.length;
    final lowStock = kInventoryItems
        .where((i) => i.stock <= i.lowStockThreshold)
        .length;
    final outOfStock = kInventoryItems.where((i) => i.stock == 0).length;
    final totalCrates = kCrateStocks.fold<double>(0, (s, c) => s + c.available);

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _summaryCard(
            'Total SKUs',
            '$totalItems',
            FontAwesomeIcons.layerGroup,
            blueMain,
          ),
          const SizedBox(width: 10),
          _summaryCard(
            'Low Stock',
            '$lowStock',
            FontAwesomeIcons.triangleExclamation,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          _summaryCard(
            'Out of Stock',
            '$outOfStock',
            FontAwesomeIcons.ban,
            danger,
          ),
          const SizedBox(width: 10),
          _summaryCard(
            'Empty Crates',
            '${totalCrates.toInt()}',
            FontAwesomeIcons.beerMugEmpty,
            success,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isDark ? _dCard : _lCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: _subtext,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Divider(height: 1, color: _border),
          TabBar(
            controller: _tabController,
            labelColor: blueMain,
            unselectedLabelColor: _subtext,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            indicatorColor: blueMain,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Empty Crates'),
              Tab(text: 'Activity Log'),
            ],
          ),
        ],
      ),
    );
  }

  // ── PRODUCTS TAB ─────────────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    return Column(
      children: [
        _buildSupplierFilter(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _filteredItems.length,
            itemBuilder: (_, i) => _buildProductRow(_filteredItems[i]),
          ),
        ),
      ],
    );
  }

  List<InventoryItem> get _filteredItems {
    if (_selectedSupplierId == 'all') return kInventoryItems;
    return kInventoryItems
        .where((i) => i.supplierId == _selectedSupplierId)
        .toList();
  }

  Widget _buildSupplierFilter() {
    return Container(
      color: _surface,
      child: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _filterChip('All', 'all'),
                ...kSuppliers.map(
                  (s) => _filterChip(s.name.split(' ').first, s.id),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String id) {
    final active = _selectedSupplierId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSupplierId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: active ? blueMain : (_isDark ? _dCard : _lCard),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? blueMain : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : _subtext,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(InventoryItem item) {
    final isLow = item.stock > 0 && item.stock <= item.lowStockThreshold;
    final isOut = item.stock == 0;
    final supplier = kSuppliers.firstWhere(
      (s) => s.id == item.supplierId,
      orElse: () =>
          Supplier(id: '', name: 'Unknown', crateGroup: CrateGroup.nbPlc),
    );
    final crateStock = kCrateStocks.firstWhere(
      (c) => c.group == supplier.crateGroup,
      orElse: () => CrateStock(group: CrateGroup.nbPlc),
    );

    Color statusColor = success;
    String statusLabel = 'In Stock';
    if (isOut) {
      statusColor = danger;
      statusLabel = 'Out of Stock';
    } else if (isLow) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Low Stock';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOut
              ? danger.withOpacity(0.3)
              : isLow
              ? const Color(0xFFF59E0B).withOpacity(0.3)
              : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supplier.name,
                    style: TextStyle(fontSize: 12, color: _subtext),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.beerMugEmpty,
                        size: 10,
                        color: supplier.crateGroup.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Empty crates (${supplier.crateGroup.label}): ${crateStock.available.toInt()} available',
                        style: TextStyle(fontSize: 11, color: _subtext),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.stock.toStringAsFixed(item.stock % 1 == 0 ? 0 : 1)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isOut
                        ? danger
                        : isLow
                        ? const Color(0xFFF59E0B)
                        : _text,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 11, color: _subtext),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showUpdateStockDialog(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: blueMain.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: blueMain.withOpacity(0.2)),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: blueMain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── CRATES TAB ───────────────────────────────────────────────────────────────
  Widget _buildCratesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDark ? _dCard : _lCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.circleInfo,
                    size: 14,
                    color: blueMain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How Empty Crates Work',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Empty crates are pooled by supplier group — all bottles from the same group share the same crate type. When a customer returns crates, add them to the relevant group. When restocking a product, crates are drawn from that group.',
                style: TextStyle(fontSize: 13, color: _subtext, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Crate Groups',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        const SizedBox(height: 12),
        ...kCrateStocks.map((cs) => _buildCrateGroupCard(cs)),
      ],
    );
  }

  Widget _buildCrateGroupCard(CrateStock cs) {
    final linkedProducts = kInventoryItems
        .where((item) {
          final supplier = kSuppliers.firstWhere(
            (s) => s.id == item.supplierId,
            orElse: () =>
                Supplier(id: '', name: 'Unknown', crateGroup: CrateGroup.nbPlc),
          );
          return supplier.crateGroup == cs.group;
        })
        .map((i) => i.productName)
        .toList();

    final linkedSuppliers = kSuppliers
        .where((s) => s.crateGroup == cs.group)
        .map((s) => s.name)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.group.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.group.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    FontAwesomeIcons.beerMugEmpty,
                    color: cs.group.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cs.group.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linkedSuppliers.isEmpty
                            ? 'No suppliers linked'
                            : linkedSuppliers.join(', '),
                        style: TextStyle(fontSize: 12, color: _subtext),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${cs.available.toInt()}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.available == 0 ? danger : _text,
                      ),
                    ),
                    Text(
                      'crates',
                      style: TextStyle(fontSize: 11, color: _subtext),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (linkedProducts.isNotEmpty) ...[
            Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked Products: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _subtext,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      linkedProducts.join(', '),
                      style: TextStyle(fontSize: 12, color: _subtext),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showUpdateCratesDialog(cs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.group.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.group.color.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.group.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── LOG TAB ──────────────────────────────────────────────────────────────────
  Widget _buildLogTab() {
    if (kInventoryLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.clockRotateLeft, size: 48, color: _border),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                color: _subtext,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates will appear here with date, time, and user',
              style: TextStyle(color: _subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sorted = [...kInventoryLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildLogRow(sorted[i]),
    );
  }

  Widget _buildLogRow(InventoryLog log) {
    final actionColors = {
      'restock': success,
      'adjustment': blueMain,
      'crate_update': const Color(0xFFF59E0B),
      'new_supplier': const Color(0xFF8B5CF6),
    };
    final color = actionColors[log.action] ?? blueMain;
    final diff = log.newValue - log.previousValue;
    final diffStr = diff >= 0
        ? '+${diff.toStringAsFixed(1)}'
        : diff.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              log.action == 'restock'
                  ? FontAwesomeIcons.arrowUp
                  : log.action == 'crate_update'
                  ? FontAwesomeIcons.beerMugEmpty
                  : log.action == 'new_supplier'
                  ? FontAwesomeIcons.buildingColumns
                  : FontAwesomeIcons.pen,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.user} · ${_formatLogTime(log.timestamp)}',
                  style: TextStyle(fontSize: 11, color: _subtext),
                ),
                if (log.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.note!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _subtext,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                diffStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: diff >= 0 ? success : danger,
                ),
              ),
              Text(
                '${log.previousValue.toInt()} → ${log.newValue.toInt()}',
                style: TextStyle(fontSize: 10, color: _subtext),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLogTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget _buildAddFab() {
    return GestureDetector(
      onTap: _showAddProductDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [blueLight, blueMain],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: blueMain.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FontAwesomeIcons.plus, color: Colors.white, size: 16),
            SizedBox(width: 10),
            Text(
              'Add Product',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UPDATE STOCK DIALOG ───────────────────────────────────────────────────────
  void _showUpdateStockDialog(InventoryItem item) {
    final ctrl = TextEditingController(
      text: item.stock.toStringAsFixed(item.stock % 1 == 0 ? 0 : 1),
    );
    final noteCtrl = TextEditingController();
    String action = 'restock';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? _dSurface : _lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Stock',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: blueMain,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Action',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _actionChip(
                      'restock',
                      'Restock',
                      action,
                      (v) => setB(() => action = v),
                    ),
                    const SizedBox(width: 8),
                    _actionChip(
                      'adjustment',
                      'Adjust',
                      action,
                      (v) => setB(() => action = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'New Quantity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter quantity',
                    hintStyle: TextStyle(color: _subtext),
                    filled: true,
                    fillColor: _isDark ? _dCard : _lCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    suffixText: item.subtitle,
                    suffixStyle: TextStyle(color: _subtext, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: TextStyle(fontSize: 14, color: _text),
                  decoration: InputDecoration(
                    hintText: 'Note (optional)',
                    hintStyle: TextStyle(color: _subtext),
                    filled: true,
                    fillColor: _isDark ? _dCard : _lCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: blueMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final newQty = double.tryParse(ctrl.text) ?? item.stock;
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: item.id,
                        itemName: item.productName,
                        action: action,
                        previousValue: item.stock,
                        newValue: newQty,
                        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                      );
                      setState(() {
                        item.stock = newQty;
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Save Update',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionChip(
    String value,
    String label,
    String current,
    Function(String) onTap,
  ) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? blueMain : (_isDark ? _dCard : _lCard),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? blueMain : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: active ? Colors.white : _subtext,
          ),
        ),
      ),
    );
  }

  // ── UPDATE CRATES DIALOG ──────────────────────────────────────────────────────
  void _showUpdateCratesDialog(CrateStock cs) {
    final ctrl = TextEditingController(text: cs.available.toInt().toString());
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _isDark ? _dSurface : _lSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.group.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FontAwesomeIcons.beerMugEmpty,
                      color: cs.group.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Empty Crates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      Text(
                        cs.group.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.group.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Available Empty Crates',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _subtext,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
                decoration: InputDecoration(
                  hintText: 'Number of crates',
                  hintStyle: TextStyle(color: _subtext),
                  filled: true,
                  fillColor: _isDark ? _dCard : _lCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: blueMain, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  suffixText: 'crates',
                  suffixStyle: TextStyle(color: _subtext, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: TextStyle(fontSize: 14, color: _text),
                decoration: InputDecoration(
                  hintText: 'Note e.g. "Customer returned 10 crates"',
                  hintStyle: TextStyle(color: _subtext),
                  filled: true,
                  fillColor: _isDark ? _dCard : _lCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: blueMain, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.group.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final newQty = double.tryParse(ctrl.text) ?? cs.available;
                    final log = InventoryLog(
                      timestamp: DateTime.now(),
                      user: 'John Cashier',
                      itemId: 'crate_${cs.group.name}',
                      itemName: '${cs.group.label} Crates',
                      action: 'crate_update',
                      previousValue: cs.available,
                      newValue: newQty,
                      note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                    );
                    setState(() {
                      cs.available = newQty;
                      kInventoryLogs.add(log);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Update',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ADD PRODUCT DIALOG ────────────────────────────────────────────────────────
  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    String selectedSupplierId = kSuppliers.first.id;
    final stockCtrl = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? _dSurface : _lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add New Product',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Product will be added to inventory tracking',
                  style: TextStyle(fontSize: 13, color: _subtext),
                ),
                const SizedBox(height: 20),
                _inputField('Product Name', nameCtrl, 'e.g. Trophy Lager'),
                const SizedBox(height: 12),
                _inputField(
                  'Type / Packaging',
                  subtitleCtrl,
                  'e.g. Crate, Can, Keg',
                ),
                const SizedBox(height: 12),
                Text(
                  'Supplier',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isDark ? _dCard : _lCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSupplierId,
                      dropdownColor: _isDark ? _dCard : _lSurface,
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      isExpanded: true,
                      onChanged: (v) => setB(() => selectedSupplierId = v!),
                      items: kSuppliers
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _inputField('Opening Stock', stockCtrl, '0', isNumber: true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final newItem = InventoryItem(
                        id: 'i${DateTime.now().millisecondsSinceEpoch}',
                        productName: nameCtrl.text.trim(),
                        subtitle: subtitleCtrl.text.trim().isEmpty
                            ? 'Unit'
                            : subtitleCtrl.text.trim(),
                        supplierId: selectedSupplierId,
                        icon: FontAwesomeIcons.wineBottle,
                        color: blueMain,
                        stock: double.tryParse(stockCtrl.text) ?? 0,
                      );
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: newItem.id,
                        itemName: newItem.productName,
                        action: 'restock',
                        previousValue: 0,
                        newValue: newItem.stock,
                        note: 'New product added to inventory',
                      );
                      setState(() {
                        kInventoryItems.add(newItem);
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Add to Inventory',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _subtext,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(fontSize: 14, color: _text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _subtext),
            filled: true,
            fillColor: _isDark ? _dCard : _lCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: blueMain, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ── ADD SUPPLIER DIALOG ───────────────────────────────────────────────────────
  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    CrateGroup selectedGroup = CrateGroup.nbPlc;
    bool trackInventory = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? _dSurface : _lSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add New Supplier',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a crate group so empty crates are tracked correctly',
                  style: TextStyle(fontSize: 13, color: _subtext),
                ),
                const SizedBox(height: 20),
                _inputField(
                  'Supplier / Company Name',
                  nameCtrl,
                  'e.g. SABMiller Nigeria',
                ),
                const SizedBox(height: 16),
                Text(
                  'Crate Group',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _subtext,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CrateGroup.values.map((g) {
                    final active = selectedGroup == g;
                    return GestureDetector(
                      onTap: () => setB(() => selectedGroup = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? g.color.withOpacity(0.15)
                              : (_isDark ? _dCard : _lCard),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active ? g.color : _border,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: g.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              g.label,
                              style: TextStyle(
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
                                color: active ? g.color : _subtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setB(() => trackInventory = !trackInventory),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: trackInventory ? blueMain : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: trackInventory ? blueMain : _border,
                            width: 2,
                          ),
                        ),
                        child: trackInventory
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Track inventory for this supplier',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final newSupplier = Supplier(
                        id: 's${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        crateGroup: selectedGroup,
                        trackInventory: trackInventory,
                      );
                      final log = InventoryLog(
                        timestamp: DateTime.now(),
                        user: 'John Cashier',
                        itemId: newSupplier.id,
                        itemName: newSupplier.name,
                        action: 'new_supplier',
                        previousValue: 0,
                        newValue: 0,
                        note: 'Crate group: ${selectedGroup.label}',
                      );
                      setState(() {
                        kSuppliers.add(newSupplier);
                        kInventoryLogs.add(log);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/role_guard.dart';

// Sentinel value meaning "no warehouse filter applied"
const int _kAllWarehouses = -1;

// ── Role config ──────────────────────────────────────────────────────────────
const _roleOptions = [
  _RoleOption('CEO',         'ceo',         5, Color(0xFFFEF08A)),
  _RoleOption('Manager',     'manager',     4, Color(0xFFA855F7)),
  _RoleOption('Storekeeper', 'storekeeper', 3, Color(0xFF34D399)),
  _RoleOption('Cashier',     'cashier',     2, Color(0xFF3B82F6)),
  _RoleOption('Rider',       'rider',       1, Color(0xFFF97316)),
  _RoleOption('Cleaner',     'cleaner',     1, Color(0xFF94A3B8)),
];

class _RoleOption {
  final String label;
  final String value;
  final int tier;
  final Color color;
  const _RoleOption(this.label, this.value, this.tier, this.color);
}

_RoleOption _roleFor(String role) =>
    _roleOptions.firstWhere((r) => r.value == role.toLowerCase(),
        orElse: () => _roleOptions.last);

// ── Screen ───────────────────────────────────────────────────────────────────
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _search = '';
  int _warehouseFilter = _kAllWarehouses;
  List<WarehouseData> _warehouses = [];

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg      => _isDark ? dBg      : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text    => _isDark ? dText    : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border  => _isDark ? dBorder  : lBorder;
  Color get _card    => _isDark ? dCard    : lCard;

  @override
  void initState() {
    super.initState();
    (database.select(database.warehouses)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .listen((wh) {
      if (mounted) setState(() => _warehouses = wh);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: const MenuButton(),
          title: const AppBarHeader(
            icon: FontAwesomeIcons.usersGear,
            title: 'Staff',
            subtitle: 'Management',
          ),
          actions: [
            const NotificationBell(),
            SizedBox(width: context.getRSize(8)),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(context.getRSize(64)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.getRSize(16),
                0,
                context.getRSize(16),
                context.getRSize(12),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search staff…',
                  prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass,
                      size: context.getRSize(14), color: _subtext),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: context.getRSize(10),
                      horizontal: context.getRSize(14)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: blueMain),
                  ),
                ),
                style: TextStyle(color: _text, fontSize: context.getRFontSize(14)),
              ),
            ),
          ),
        ),
        drawer: const AppDrawer(activeRoute: 'staff'),
        floatingActionButton: RoleGuard(
          minTier: 4,
          fallback: const SizedBox.shrink(),
          child: FloatingActionButton.extended(
            onPressed: () => _showStaffSheet(context),
            backgroundColor: blueMain,
            icon: const Icon(FontAwesomeIcons.userPlus, color: Colors.white),
            label: Text('Add Staff',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14))),
          ),
        ),
        body: StreamBuilder<List<UserData>>(
          stream: database.select(database.users).watch(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data ?? [];

            // Apply warehouse filter
            final warehouseFiltered = _warehouseFilter == _kAllWarehouses
                ? all
                : all.where((u) => u.warehouseId == _warehouseFilter).toList();

            // Apply search filter
            final filtered = _search.isEmpty
                ? warehouseFiltered
                : warehouseFiltered.where((u) =>
                    u.name.toLowerCase().contains(_search) ||
                    u.role.toLowerCase().contains(_search)).toList();

            return Column(
              children: [
                // ── Warehouse filter chips ──────────────────────────────
                if (_warehouses.isNotEmpty)
                  SizedBox(
                    height: context.getRSize(44),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: context.getRSize(16), vertical: context.getRSize(6)),
                      children: [
                        _filterChip('All', _warehouseFilter == _kAllWarehouses,
                            () => setState(() => _warehouseFilter = _kAllWarehouses)),
                        for (final wh in _warehouses)
                          _filterChip(wh.name, _warehouseFilter == wh.id,
                              () => setState(() => _warehouseFilter = wh.id)),
                      ],
                    ),
                  ),

                // ── Staff list ─────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FontAwesomeIcons.usersSlash,
                                  size: context.getRSize(48),
                                  color: _subtext.withValues(alpha: 0.4)),
                              SizedBox(height: context.getRSize(12)),
                              Text(
                                _search.isEmpty
                                    ? 'No staff in this warehouse.'
                                    : 'No results for "$_search".',
                                style: TextStyle(
                                    color: _subtext,
                                    fontSize: context.getRFontSize(14)),
                              ),
                            ],
                          ),
                        )
                      : _buildGroupedList(filtered),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(right: context.getRSize(8)),
        padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(14), vertical: context.getRSize(4)),
        decoration: BoxDecoration(
          color: selected ? blueMain : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? blueMain : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _subtext,
            fontSize: context.getRFontSize(12),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<UserData> users) {
    final groups = <int, List<UserData>>{};
    for (final u in users) {
      groups.putIfAbsent(u.roleTier, () => []).add(u);
    }
    final sortedTiers = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.getRSize(16),
        context.getRSize(12),
        context.getRSize(16),
        context.getRSize(100),
      ),
      children: [
        for (final tier in sortedTiers) ...[
          _buildSectionHeader(tier, groups[tier]!.length),
          SizedBox(height: context.getRSize(8)),
          for (final user in groups[tier]!) ...[
            _buildStaffCard(context, user),
            SizedBox(height: context.getRSize(10)),
          ],
          SizedBox(height: context.getRSize(8)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(int tier, int count) {
    final roleInfo = _roleOptions.firstWhere(
      (r) => r.tier == tier,
      orElse: () => _roleOptions.last,
    );
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(10),
              vertical: context.getRSize(4)),
          decoration: BoxDecoration(
            color: roleInfo.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: roleInfo.color.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Tier $tier',
            style: TextStyle(
              color: roleInfo.color,
              fontSize: context.getRFontSize(11),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: context.getRSize(8)),
        Text(
          '$count ${count == 1 ? 'member' : 'members'}',
          style: TextStyle(color: _subtext, fontSize: context.getRFontSize(12)),
        ),
      ],
    );
  }

  Widget _buildStaffCard(BuildContext context, UserData user) {
    final roleInfo = _roleFor(user.role);
    final avatarColor = _parseColor(user.avatarColor) ?? roleInfo.color;
    final initials = _initials(user.name);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.getRSize(14)),
        child: Row(
          children: [
            // Avatar
            Container(
              width: context.getRSize(48),
              height: context.getRSize(48),
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: avatarColor.withValues(alpha: 0.5), width: 2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: avatarColor,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(16),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.getRSize(14)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.bold,
                      fontSize: context.getRFontSize(15),
                    ),
                  ),
                  SizedBox(height: context.getRSize(4)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.getRSize(8),
                            vertical: context.getRSize(2)),
                        decoration: BoxDecoration(
                          color: roleInfo.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleInfo.label,
                          style: TextStyle(
                            color: roleInfo.color,
                            fontSize: context.getRFontSize(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions (manager+ only)
            RoleGuard(
              minTier: 4,
              fallback: const SizedBox.shrink(),
              child: PopupMenuButton<String>(
                icon: Icon(FontAwesomeIcons.ellipsisVertical,
                    size: context.getRSize(16), color: _subtext),
                color: _surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'edit') _showStaffSheet(context, user: user);
                  if (action == 'delete') _confirmDelete(context, user);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.penToSquare,
                            size: context.getRSize(14), color: blueMain),
                        SizedBox(width: context.getRSize(10)),
                        Text('Edit',
                            style: TextStyle(
                                color: _text,
                                fontSize: context.getRFontSize(14))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.trash,
                            size: context.getRSize(14), color: danger),
                        SizedBox(width: context.getRSize(10)),
                        Text('Delete',
                            style: TextStyle(
                                color: danger,
                                fontSize: context.getRFontSize(14))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffSheet(BuildContext context, {UserData? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(user: user, warehouses: _warehouses),
    );
  }

  void _confirmDelete(BuildContext context, UserData user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Staff',
            style: TextStyle(
                color: _text,
                fontWeight: FontWeight.bold,
                fontSize: context.getRFontSize(16))),
        content: Text(
          'Remove ${user.name} from staff? This cannot be undone.',
          style: TextStyle(color: _subtext, fontSize: context.getRFontSize(14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: _subtext, fontSize: context.getRFontSize(14))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await (database.delete(database.users)
                    ..where((t) => t.id.equals(user.id)))
                  .go();
            },
            child: Text('Remove',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14))),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color? _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ── Add / Edit bottom sheet ──────────────────────────────────────────────────
class _StaffFormSheet extends StatefulWidget {
  final UserData? user;
  final List<WarehouseData> warehouses;
  const _StaffFormSheet({this.user, required this.warehouses});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _pinCtrl;
  late _RoleOption _selectedRole;
  int? _selectedWarehouseId;
  bool _showPin = false;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _bg     => _isDark ? dBg      : lBg;
  Color get _text   => _isDark ? dText    : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder  : lBorder;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _pinCtrl  = TextEditingController(text: u?.pin  ?? '');
    _selectedRole = u != null ? _roleFor(u.role) : _roleOptions[3]; // default Cashier
    _selectedWarehouseId = u?.warehouseId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, __, ___) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(context.getRSize(20)),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: context.getRSize(40),
                    height: context.getRSize(4),
                    margin: EdgeInsets.only(bottom: context.getRSize(16)),
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _isEditing ? 'Edit Staff' : 'Add Staff',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(18),
                  ),
                ),
                SizedBox(height: context.getRSize(20)),
                // Name
                _label('Full Name'),
                SizedBox(height: context.getRSize(6)),
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(
                      color: _text, fontSize: context.getRFontSize(14)),
                  decoration: _inputDecoration('e.g. Jane Okoro'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                SizedBox(height: context.getRSize(14)),
                // PIN
                _label('4-Digit PIN'),
                SizedBox(height: context.getRSize(6)),
                TextFormField(
                  controller: _pinCtrl,
                  obscureText: !_showPin,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: _text, fontSize: context.getRFontSize(14)),
                  decoration: _inputDecoration('****').copyWith(
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPin
                              ? FontAwesomeIcons.eyeSlash
                              : FontAwesomeIcons.eye,
                          size: context.getRSize(14),
                          color: _subtext),
                      onPressed: () => setState(() => _showPin = !_showPin),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'PIN is required';
                    if (v.length != 4) return 'PIN must be 4 digits';
                    return null;
                  },
                ),
                SizedBox(height: context.getRSize(14)),
                // Role
                _label('Role'),
                SizedBox(height: context.getRSize(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.getRSize(12),
                      vertical: context.getRSize(4)),
                  decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(10),
                    color: _bg,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_RoleOption>(
                      value: _selectedRole,
                      isExpanded: true,
                      dropdownColor: _surface,
                      style: TextStyle(
                          color: _text, fontSize: context.getRFontSize(14)),
                      items: _roleOptions.map((r) {
                        return DropdownMenuItem<_RoleOption>(
                          value: r,
                          child: Row(
                            children: [
                              Container(
                                width: context.getRSize(12),
                                height: context.getRSize(12),
                                margin: EdgeInsets.only(right: context.getRSize(8)),
                                decoration: BoxDecoration(
                                  color: r.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(r.label),
                              SizedBox(width: context.getRSize(6)),
                              Text(
                                '(Tier ${r.tier})',
                                style: TextStyle(
                                    color: _subtext,
                                    fontSize: context.getRFontSize(11)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (r) {
                        if (r != null) setState(() => _selectedRole = r);
                      },
                    ),
                  ),
                ),
                // Warehouse assignment
                if (widget.warehouses.isNotEmpty) ...[
                  SizedBox(height: context.getRSize(14)),
                  _label('Assign to Warehouse (optional)'),
                  SizedBox(height: context.getRSize(6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.getRSize(12),
                        vertical: context.getRSize(4)),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(10),
                      color: _bg,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedWarehouseId,
                        isExpanded: true,
                        dropdownColor: _surface,
                        style: TextStyle(
                            color: _text, fontSize: context.getRFontSize(14)),
                        hint: Text('No warehouse assigned',
                            style: TextStyle(
                                color: _subtext,
                                fontSize: context.getRFontSize(14))),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No warehouse',
                                style: TextStyle(color: _subtext)),
                          ),
                          for (final wh in widget.warehouses)
                            DropdownMenuItem<int?>(
                              value: wh.id,
                              child: Row(
                                children: [
                                  Icon(Icons.warehouse_outlined,
                                      size: context.getRSize(14),
                                      color: blueMain),
                                  SizedBox(width: context.getRSize(8)),
                                  Text(wh.name),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedWarehouseId = v),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: context.getRSize(24)),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueMain,
                      padding: EdgeInsets.symmetric(
                          vertical: context.getRSize(14)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _save,
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Add Staff Member',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(15),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom +
                        context.getRSize(8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: _subtext,
          fontSize: context.getRFontSize(12),
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: _subtext, fontSize: context.getRFontSize(14)),
        filled: true,
        fillColor: _bg,
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.getRSize(14),
            vertical: context.getRSize(12)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: blueMain),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final pin  = _pinCtrl.text.trim();
    final colorHex = _colorHex(_selectedRole.color);

    if (_isEditing) {
      await (database.update(database.users)
            ..where((t) => t.id.equals(widget.user!.id)))
          .write(UsersCompanion(
            name:        Value(name),
            pin:         Value(pin),
            role:        Value(_selectedRole.value),
            roleTier:    Value(_selectedRole.tier),
            avatarColor: Value(colorHex),
            warehouseId: Value(_selectedWarehouseId),
          ));
    } else {
      await database.into(database.users).insert(
            UsersCompanion.insert(
              name:        name,
              pin:         pin,
              role:        _selectedRole.value,
              roleTier:    Value(_selectedRole.tier),
              avatarColor: Value(colorHex),
              warehouseId: Value(_selectedWarehouseId),
            ),
          );
    }

    if (mounted) Navigator.pop(context);
  }

  String _colorHex(Color c) {
    final r = c.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = c.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = c.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}

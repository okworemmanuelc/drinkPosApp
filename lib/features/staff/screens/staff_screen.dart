import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../core/widgets/amber_fab.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';

import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/role_guard.dart';
import 'staff_constants.dart';
import 'staff_details_screen.dart';
import '../../../shared/widgets/fluid_menu.dart';

const int _kAllWarehouses = -1;

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _searchQuery = '';
  int _selectedWarehouseFilter = _kAllWarehouses;
  List<WarehouseData> _warehouses = [];
  List<UserData> _users = [];
  StreamSubscription<List<UserData>>? _usersSub;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext => Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
  Color get _border => Theme.of(context).dividerColor;
  Color get _card => Theme.of(context).cardColor;

  @override
  void initState() {
    super.initState();
    database.select(database.warehouses).get().then((ws) {
      if (mounted) setState(() => _warehouses = ws);
    });
    _usersSub = database.select(database.users).watch().listen((data) {
      if (mounted) setState(() => _users = data);
    });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _surface,
            elevation: 0,
            leading: const MenuButton(),
            title: const AppBarHeader(
              icon: FontAwesomeIcons.userTie,
              title: 'Staff Management',
              subtitle: 'Manage your team & roles',
            ),
            actions: const [
              NotificationBell(),
              SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name...',
                    hintStyle: TextStyle(color: _subtext, fontSize: 14),
                    prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass,
                        size: 16, color: _subtext),
                    filled: true,
                    fillColor: _bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          drawer: const AppDrawer(activeRoute: 'staff'),
          body: _buildBody(),
          floatingActionButton: RoleGuard(
            minTier: 4,
            fallback: const SizedBox.shrink(),
            child: AmberFAB(
              onPressed: () => _showStaffSheet(context),
              icon: FontAwesomeIcons.plus,
              label: 'Add Staff',
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    final listRaw = _users;
    var list = [...listRaw];

    if (_selectedWarehouseFilter != _kAllWarehouses) {
      list = list.where((u) => u.warehouseId == _selectedWarehouseFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((u) => u.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Column(
      children: [
        _buildWarehouseFilters(),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.usersSlash,
                          size: 48, color: _subtext.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No staff found',
                          style: TextStyle(color: _subtext, fontSize: 16)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    for (final tier in [5, 4, 3, 2, 1]) ...[
                      if (list.any((u) => roleFor(u.role).tier == tier)) ...[
                        _buildSectionHeader(tier,
                            list.where((u) => roleFor(u.role).tier == tier).length),
                        const SizedBox(height: 8),
                        ...list
                            .where((u) => roleFor(u.role).tier == tier)
                            .map((u) => _buildStaffCard(context, u)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWarehouseFilters() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _filterChip('All', _kAllWarehouses),
          for (final w in _warehouses) _filterChip(w.name, w.id),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int id) {
    final active = _selectedWarehouseFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedWarehouseFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? blueMain : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? blueMain : _border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _text,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int tier, int count) {
    final roleInfo = roleOptions.firstWhere(
      (r) => r.tier == tier,
      orElse: () => roleOptions.last,
    );
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: roleInfo.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '  ${roleInfo.label.toUpperCase()}S' ,
          style: TextStyle(
              color: _subtext,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
        const Spacer(),
        Text(
          '$count members',
          style: TextStyle(color: _subtext.withValues(alpha: 0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStaffCard(BuildContext context, UserData user) {
    final roleInfo = roleFor(user.role);
    final avatarColor = _parseColor(user.avatarColor) ?? roleInfo.color;
    final initials = _initials(user.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDetailsScreen(
                user: user,
                warehouses: _warehouses,
              ),
            ),
          );
        },
        onLongPress: () => _showStaffActions(context, user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(context.getRSize(14)),
          child: Row(
            children: [
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
              RoleGuard(
                minTier: 4,
                fallback: const SizedBox.shrink(),
                child: IconButton(
                  onPressed: () => _showStaffActions(context, user),
                  icon: Icon(FontAwesomeIcons.ellipsisVertical,
                      size: context.getRSize(16), color: _subtext.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
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

  void _showStaffActions(BuildContext context, UserData user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StaffActionSheet(
        user: user,
        onEdit: () {
          Navigator.pop(ctx);
          _showStaffSheet(context, user: user);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(context, user);
        },
        onView: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDetailsScreen(
                user: user,
                warehouses: _warehouses,
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserData user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Staff',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${user.name} from the system?',
            style: TextStyle(color: _subtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _subtext)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Stub — no DB delete in this version
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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

  Color? _parseColor(String color) {
    try {
      return Color(int.parse(color.replaceAll('#', 'FF'), radix: 16));
    } catch (_) {
      return null;
    }
  }
}

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
  late RoleOption _selectedRole;
  int? _selectedWarehouseId;
  bool _showPin = false;
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext => Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
  Color get _border => Theme.of(context).dividerColor;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _pinCtrl  = TextEditingController(text: u?.pin  ?? '');
    _selectedRole = u != null ? roleFor(u.role) : roleOptions[3]; // default Cashier
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
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: context.bottomInset,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _subtext.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    widget.user == null ? 'Add New Staff' : 'Edit Staff Details',
                    style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Name field
                  Text('Full Name', style: TextStyle(color: _subtext, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: _text),
                    decoration: _inputDecoration('Enter full name'),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // PIN field
                  Text('Access PIN (4 Digits)', style: TextStyle(color: _subtext, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pinCtrl,
                    style: TextStyle(color: _text),
                    obscureText: !_showPin,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Enter 4-digit PIN').copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showPin = !_showPin),
                        icon: Icon(
                          _showPin ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                          size: 16,
                          color: _subtext,
                        ),
                      ),
                    ),
                    validator: (v) => v!.length != 4 ? 'PIN must be 4 digits' : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  FluidMenu<RoleOption>(
                    label: 'Role & Access Level',
                    value: _selectedRole,
                    items: roleOptions.map((r) {
                      return FluidMenuItem<RoleOption>(
                        value: r,
                        label: r.label,
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                        ),
                      );
                    }).toList(),
                    onChanged: (r) => setState(() => _selectedRole = r!),
                  ),

                  const SizedBox(height: 16),
                  
                  FluidMenu<int>(
                    label: 'Assigned Warehouse',
                    value: _selectedWarehouseId,
                    placeholder: 'Select Warehouse',
                    items: widget.warehouses.map((w) {
                      return FluidMenuItem<int>(
                        value: w.id,
                        label: w.name,
                      );
                    }).toList(),
                    onChanged: (id) => setState(() => _selectedWarehouseId = id!),
                  ),

                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        widget.user == null ? 'Create Account' : 'Save Changes',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseId == null) return;

    final name = _nameCtrl.text.trim();
    final pin  = _pinCtrl.text.trim();
    final role = _selectedRole.value;
    final tier = _selectedRole.tier;

    // Non-managers cannot be added to a warehouse that has no manager yet.
    if (tier < 4) {
      final staffInWarehouse = await (database.select(database.users)
            ..where((u) => u.warehouseId.equals(_selectedWarehouseId!)))
          .get();

      // Exclude the user being edited, then count managers.
      final otherManagers = staffInWarehouse
          .where((u) =>
              u.roleTier >= 4 &&
              (widget.user == null || u.id != widget.user!.id))
          .toList();

      if (otherManagers.isEmpty) {
        if (!mounted) return;
        final warehouseName = widget.warehouses
            .firstWhere((w) => w.id == _selectedWarehouseId,
                orElse: () => const WarehouseData(id: -1, name: 'this warehouse'))
            .name;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(FontAwesomeIcons.triangleExclamation,
                    color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 10),
                Text('No Manager Assigned',
                    style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            content: Text(
              '"$warehouseName" does not have a manager yet.\n\n'
              'You must assign a Manager (or higher) to this warehouse before adding regular staff.',
              style: TextStyle(color: _subtext, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Got it',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }
    }

    final warehouseName = widget.warehouses
        .firstWhere((w) => w.id == _selectedWarehouseId,
            orElse: () => const WarehouseData(id: -1, name: 'the warehouse'))
        .name;

    if (widget.user == null) {
      // Insert new staff member
      await database.into(database.users).insert(UsersCompanion(
        name: Value(name),
        pin: Value(pin),
        role: Value(role),
        roleTier: Value(tier),
        warehouseId: Value(_selectedWarehouseId),
      ));
    } else {
      // Update existing staff member
      await (database.update(database.users)
            ..where((u) => u.id.equals(widget.user!.id)))
          .write(UsersCompanion(
        name: Value(name),
        pin: Value(pin),
        role: Value(role),
        roleTier: Value(tier),
        warehouseId: Value(_selectedWarehouseId),
      ));
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(FontAwesomeIcons.circleCheck,
                color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$name has been successfully assigned to $warehouseName.',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _subtext.withValues(alpha: 0.5), fontSize: 14),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _StaffActionSheet extends StatelessWidget {
  final UserData user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const _StaffActionSheet({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color textColor = Theme.of(context).colorScheme.onSurface;
    final Color subtextColor = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    final roleInfo = roleFor(user.role);
    final avatarColor = _parseColor(user.avatarColor) ?? roleInfo.color;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: subtextColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(
                  child: Text(
                    _initials(user.name),
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleInfo.label,
                      style: TextStyle(
                        color: roleInfo.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'AVAILABLE ACTIONS',
            style: TextStyle(
              color: subtextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _actionTile(
            context,
            icon: FontAwesomeIcons.userPen,
            label: 'View Full Profile',
            subtitle: 'Check performance & history',
            color: Theme.of(context).colorScheme.primary,
            onTap: onView,
            isDark: Theme.of(context).brightness == Brightness.dark,
            bg: bgColor,
            text: textColor,
            subtext: subtextColor,
          ),
          const SizedBox(height: 12),
          _actionTile(
            context,
            icon: FontAwesomeIcons.penToSquare,
            label: 'Edit Details',
            subtitle: 'Update role or access PIN',
            color: Colors.orange,
            onTap: onEdit,
            isDark: Theme.of(context).brightness == Brightness.dark,
            bg: bgColor,
            text: textColor,
            subtext: subtextColor,
          ),
          const SizedBox(height: 12),
          _actionTile(
            context,
            icon: FontAwesomeIcons.trashCan,
            label: 'Terminate Access',
            subtitle: 'Permanently remove from team',
            color: Theme.of(context).colorScheme.error,
            onTap: onDelete,
            isDark: Theme.of(context).brightness == Brightness.dark,
            bg: bgColor,
            text: textColor,
            subtext: subtextColor,
            isDanger: true,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required Color bg,
    required Color text,
    required Color subtext,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDanger ? color.withValues(alpha: 0.1) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDanger ? color : text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtext.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: subtext.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color? _parseColor(String color) {
    try {
      return Color(int.parse(color.replaceAll('#', 'FF'), radix: 16));
    } catch (_) {
      return null;
    }
  }
}





import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/services/navigation_service.dart';
import 'warehouse_details_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  List<WarehouseData> _warehouses = [];
  StreamSubscription<List<WarehouseData>>? _warehousesSub;

  @override
  void initState() {
    super.initState();
    _warehousesSub = database.select(database.warehouses).watch().listen((data) {
      if (mounted) setState(() => _warehouses = data);
    });
  }

  @override
  void dispose() {
    _warehousesSub?.cancel();
    super.dispose();
  }

  // ── Add Warehouse ──────────────────────────────────────────────────────────
  void _showAddSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: ctx.bottomInset,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              rSize(ctx, 24),
              rSize(ctx, 20),
              rSize(ctx, 24),
              rSize(ctx, 32),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                  SizedBox(height: rSize(ctx, 20)),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(rSize(ctx, 10)),
                        decoration: BoxDecoration(
                          color: blueMain.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          FontAwesomeIcons.warehouse,
                          color: blueMain,
                          size: rSize(ctx, 18),
                        ),
                      ),
                      SizedBox(width: rSize(ctx, 12)),
                      Text(
                        'New Warehouse',
                        style: TextStyle(
                          fontSize: rFontSize(ctx, 18),
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: rSize(ctx, 24)),

                  // Name
                  _sheetField(
                    ctx,
                    controller: nameCtrl,
                    label: 'Warehouse Name',
                    hint: 'e.g. Main Store, Annex B',
                    icon: Icons.warehouse_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  SizedBox(height: rSize(ctx, 16)),

                  // Location
                  _sheetField(
                    ctx,
                    controller: locationCtrl,
                    label: 'Location / Address (optional)',
                    hint: 'e.g. 14 Market Road, Lagos',
                    icon: Icons.location_on_outlined,
                  ),
                  SizedBox(height: rSize(ctx, 28)),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: rSize(ctx, 52),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [blueLight, blueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: blueMain.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                try {
                                  await database.into(database.warehouses).insert(
                                        WarehousesCompanion.insert(
                                          name: nameCtrl.text.trim(),
                                          location: locationCtrl.text.trim().isEmpty
                                              ? const Value.absent()
                                              : Value(locationCtrl.text.trim()),
                                        ),
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Warehouse',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit Warehouse ─────────────────────────────────────────────────────────
  void _showEditSheet(BuildContext context, WarehouseData warehouse) {
    final nameCtrl = TextEditingController(text: warehouse.name);
    final locationCtrl = TextEditingController(text: warehouse.location ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: ctx.bottomInset,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              rSize(ctx, 24),
              rSize(ctx, 20),
              rSize(ctx, 24),
              rSize(ctx, 32),
            ),
            child: Form(
              key: formKey,
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
                  SizedBox(height: rSize(ctx, 20)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(rSize(ctx, 10)),
                        decoration: BoxDecoration(
                          color: blueMain.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          FontAwesomeIcons.penToSquare,
                          color: blueMain,
                          size: rSize(ctx, 18),
                        ),
                      ),
                      SizedBox(width: rSize(ctx, 12)),
                      Text(
                        'Edit Warehouse',
                        style: TextStyle(
                          fontSize: rFontSize(ctx, 18),
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: rSize(ctx, 24)),
                  _sheetField(
                    ctx,
                    controller: nameCtrl,
                    label: 'Warehouse Name',
                    hint: 'e.g. Main Store',
                    icon: Icons.warehouse_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  SizedBox(height: rSize(ctx, 16)),
                  _sheetField(
                    ctx,
                    controller: locationCtrl,
                    label: 'Location / Address (optional)',
                    hint: 'e.g. 14 Market Road, Lagos',
                    icon: Icons.location_on_outlined,
                  ),
                  SizedBox(height: rSize(ctx, 28)),
                  SizedBox(
                    width: double.infinity,
                    height: rSize(ctx, 52),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [blueLight, blueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: blueMain.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                await (database.update(database.warehouses)
                                      ..where((t) => t.id.equals(warehouse.id)))
                                    .write(
                                      WarehousesCompanion(
                                        name: Value(nameCtrl.text.trim()),
                                        location: locationCtrl.text.trim().isEmpty
                                            ? const Value(null)
                                            : Value(locationCtrl.text.trim()),
                                      ),
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete Warehouse ───────────────────────────────────────────────────────
  Future<void> _confirmDelete(
    BuildContext context,
    WarehouseData warehouse,
  ) async {
    final rows = await (database.select(database.inventory)
          ..where((t) => t.warehouseId.equals(warehouse.id)))
        .get();
    final stock = rows.fold<int>(0, (sum, r) => sum + r.quantity);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Warehouse',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${warehouse.name}"?',
              style: TextStyle(color: _subtext),
            ),
            if (stock > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This warehouse has $stock units in stock. Deleting it will also remove its inventory records.',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _subtext)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete inventory first (FK), then warehouse
              await (database.delete(
                database.inventory,
              )..where((t) => t.warehouseId.equals(warehouse.id))).go();
              await (database.delete(
                database.warehouses,
              )..where((t) => t.id.equals(warehouse.id))).go();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, _, _) => SharedScaffold(
        activeRoute: 'warehouse',
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: const MenuButton(),
          title: const AppBarHeader(
            icon: FontAwesomeIcons.warehouse,
            title: 'Warehouses',
            subtitle: 'Manage Storage Locations',
          ),
          actions: [
            const NotificationBell(),
            SizedBox(width: rSize(context, 8)),
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
            onPressed: () => _showAddSheet(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Add Warehouse',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        body: Builder(
          builder: (context) {
            final warehouses = _warehouses;

            if (warehouses.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                rSize(context, 16),
                rSize(context, 16),
                rSize(context, 16),
                rSize(context, 100),
              ),
              itemCount: warehouses.length,
              itemBuilder: (context, index) =>
                  _buildWarehouseCard(context, warehouses[index]),
            );
          },
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(rSize(context, 24)),
            decoration: BoxDecoration(
              color: blueMain.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.warehouse,
              size: rSize(context, 40),
              color: blueMain.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: rSize(context, 20)),
          Text(
            'No Warehouses Yet',
            style: TextStyle(
              fontSize: rFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          SizedBox(height: rSize(context, 8)),
          Text(
            'Tap "Add Warehouse" to create\nyour first storage location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rFontSize(context, 14),
              color: _subtext,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Warehouse card ─────────────────────────────────────────────────────────
  Widget _buildWarehouseCard(BuildContext context, WarehouseData warehouse) {
    return _WarehouseCard(
      warehouse: warehouse,
      onEdit: () => _showEditSheet(context, warehouse),
      onDelete: () => _confirmDelete(context, warehouse),
      onStaff: () => navigationService.setIndex(8),
    );
  }

  // ── Shared bottom-sheet text field ─────────────────────────────────────────
  Widget _sheetField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: _text, fontSize: rFontSize(context, 15)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _subtext),
        hintStyle: TextStyle(
          color: _subtext.withValues(alpha: 0.5),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _subtext, size: 20),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blueMain, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// ── Reactive warehouse card ────────────────────────────────────────────────────
class _WarehouseCard extends StatefulWidget {
  final WarehouseData warehouse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStaff;

  const _WarehouseCard({
    required this.warehouse,
    required this.onEdit,
    required this.onDelete,
    required this.onStaff,
  });

  @override
  State<_WarehouseCard> createState() => _WarehouseCardState();
}

class _WarehouseCardState extends State<_WarehouseCard> {
  List<ProductDataWithStock> _inventory = [];
  List<UserData> _staff = [];

  StreamSubscription<List<ProductDataWithStock>>? _invSub;
  StreamSubscription<List<UserData>>? _staffSub;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _isDark ? dSurface : lSurface;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _border => _isDark ? dBorder : lBorder;
  Color get _card => _isDark ? dCard : lCard;

  @override
  void initState() {
    super.initState();
    final id = widget.warehouse.id;
    _invSub = database.inventoryDao
        .watchProductDatasWithStockByWarehouse(id)
        .listen((list) {
      if (mounted) setState(() => _inventory = list);
    });
    _staffSub = database.warehousesDao
        .watchStaffByWarehouse(id)
        .listen((list) {
      if (mounted) setState(() => _staff = list);
    });
  }

  @override
  void dispose() {
    _invSub?.cancel();
    _staffSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStock = _inventory.fold<int>(0, (s, p) => s + p.totalStock);
    final productCount = _inventory.where((p) => p.totalStock > 0).length;
    final staffCount = _staff.length;

    return Container(
      margin: EdgeInsets.only(bottom: rSize(context, 14)),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main row
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WarehouseDetailsScreen(warehouse: widget.warehouse),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(rSize(context, 16)),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(rSize(context, 12)),
                    decoration: BoxDecoration(
                      color: blueMain.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(FontAwesomeIcons.warehouse,
                        color: blueMain, size: rSize(context, 20)),
                  ),
                  SizedBox(width: rSize(context, 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.warehouse.name,
                          style: TextStyle(
                            fontSize: rFontSize(context, 16),
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        if (widget.warehouse.location != null &&
                            widget.warehouse.location!.isNotEmpty) ...[
                          SizedBox(height: rSize(context, 3)),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: rSize(context, 12), color: _subtext),
                              SizedBox(width: rSize(context, 4)),
                              Expanded(
                                child: Text(
                                  widget.warehouse.location!,
                                  style: TextStyle(
                                    fontSize: rFontSize(context, 12),
                                    color: _subtext,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(FontAwesomeIcons.chevronRight,
                      size: rSize(context, 13), color: _border),
                ],
              ),
            ),
          ),

          // Stats row
          Container(
            decoration: BoxDecoration(
              color: _card,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statCell(
                    icon: FontAwesomeIcons.boxesStacked,
                    label: 'Total Units',
                    value: totalStock.toString(),
                    color: blueMain,
                  ),
                ),
                Container(width: 1, height: 36, color: _border),
                Expanded(
                  child: _statCell(
                    icon: FontAwesomeIcons.tag,
                    label: 'Products',
                    value: productCount.toString(),
                    color: AppColors.success,
                  ),
                ),
                Container(width: 1, height: 36, color: _border),
                Expanded(
                  child: _statCell(
                    icon: FontAwesomeIcons.userGroup,
                    label: 'Staff',
                    value: staffCount.toString(),
                    color: const Color(0xFFA855F7),
                  ),
                ),
              ],
            ),
          ),

          // Actions row
          Container(
            decoration: BoxDecoration(
              color: _card,
              border: Border(top: BorderSide(color: _border)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: FontAwesomeIcons.usersGear,
                    color: const Color(0xFFA855F7),
                    label: 'Staff',
                    onTap: widget.onStaff,
                  ),
                ),
                Container(width: 1, height: 36, color: _border),
                Expanded(
                  child: _actionButton(
                    icon: FontAwesomeIcons.penToSquare,
                    color: blueMain,
                    label: 'Edit',
                    onTap: widget.onEdit,
                  ),
                ),
                Container(width: 1, height: 36, color: _border),
                Expanded(
                  child: _actionButton(
                    icon: FontAwesomeIcons.trash,
                    color: AppColors.danger,
                    label: 'Delete',
                    onTap: widget.onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: rSize(context, 10),
        horizontal: rSize(context, 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: rSize(context, 12), color: color),
          SizedBox(width: rSize(context, 6)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: rFontSize(context, 13),
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: rFontSize(context, 10),
                  color: _subtext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: rSize(context, 10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: rSize(context, 13), color: color),
            SizedBox(height: rSize(context, 3)),
            Text(
              label,
              style: TextStyle(
                fontSize: rFontSize(context, 10),
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


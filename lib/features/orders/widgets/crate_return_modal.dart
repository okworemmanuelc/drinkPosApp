import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/pin_dialog.dart';

class CrateReturnModal extends StatefulWidget {
  final OrderWithItems orderWithItems;

  const CrateReturnModal({super.key, required this.orderWithItems});

  /// Shows the modal as a bottom sheet that cannot be dismissed by tapping outside.
  static Future<void> show(
    BuildContext context,
    OrderWithItems orderWithItems,
  ) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrateReturnModal(orderWithItems: orderWithItems),
    );
  }

  @override
  State<CrateReturnModal> createState() => _CrateReturnModalState();
}

class _CrateReturnModalState extends State<CrateReturnModal> {
  List<_CrateGroupRow> _groups = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _text => _isDark ? dText : lText;
  Color get _subtext => _isDark ? dSubtext : lSubtext;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _card => _isDark ? dCard : lCard;
  Color get _border => _isDark ? dBorder : lBorder;

  @override
  void initState() {
    super.initState();
    _buildGroups();
  }

  Future<void> _buildGroups() async {
    // Sum expected quantities per crate group
    final Map<int, int> groupQtys = {};
    for (final richItem in widget.orderWithItems.items) {
      final cgId = richItem.product.crateGroupId;
      if (cgId != null) {
        groupQtys[cgId] = (groupQtys[cgId] ?? 0) + richItem.item.quantity;
      }
    }

    // Load crate group names so we can show them in the UI
    final allGroups = await database.inventoryDao.getAllCrateGroups();
    final groupNameMap = {for (final g in allGroups) g.id: g.name};

    final rows = groupQtys.entries.map((entry) {
      return _CrateGroupRow(
        crateGroupId: entry.key,
        name: groupNameMap[entry.key] ?? 'Group ${entry.key}',
        expectedQty: entry.value,
        controller: TextEditingController(text: entry.value.toString()),
      );
    }).toList();

    if (mounted) {
      setState(() {
        _groups = rows;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final row in _groups) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);

    final customer = widget.orderWithItems.customer;
    if (customer == null) {
      Navigator.pop(context);
      return;
    }

    // Process groups sequentially — abort everything if any PIN is cancelled
    for (final row in _groups) {
      final entered = int.tryParse(row.controller.text) ?? row.expectedQty;

      if (entered < row.expectedQty) {
        if (!mounted) return;
        final approver = await PinDialog.show(
          context,
          minimumTier: 4,
          title: 'Manager Authorisation — Short Return',
        );
        if (approver == null) {
          // User cancelled the PIN dialog — abort the whole confirmation
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      await database.customersDao.updateCrateBalance(
        customer.id,
        row.crateGroupId,
        entered,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(20)),
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.boxOpen,
                      color: Colors.orange,
                      size: context.getRSize(18),
                    ),
                    SizedBox(width: context.getRSize(10)),
                    Text(
                      'Record Crate Returns',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                        fontSize: context.getRFontSize(17),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.getRSize(6)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(20)),
                child: Text(
                  'Enter the number of crates returned for each group.',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                ),
              ),
              SizedBox(height: context.getRSize(14)),
              Divider(height: 1, color: _border),

              // Crate group rows
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: EdgeInsets.all(context.getRSize(20)),
                        children: [
                          for (final row in _groups)
                            Container(
                              margin: EdgeInsets.only(
                                bottom: context.getRSize(12),
                              ),
                              padding: EdgeInsets.all(context.getRSize(14)),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.name,
                                          style: TextStyle(
                                            color: _text,
                                            fontWeight: FontWeight.w600,
                                            fontSize: context.getRFontSize(14),
                                          ),
                                        ),
                                        SizedBox(height: context.getRSize(2)),
                                        Text(
                                          'Expected: ${row.expectedQty}',
                                          style: TextStyle(
                                            color: _subtext,
                                            fontSize: context.getRFontSize(12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: context.getRSize(72),
                                    child: TextField(
                                      controller: row.controller,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: context.getRFontSize(16),
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: context.getRSize(8),
                                          horizontal: context.getRSize(8),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              BorderSide(color: _border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              BorderSide(color: _border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              const BorderSide(color: blueMain),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),

              // Action buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.getRSize(20),
                  context.getRSize(12),
                  context.getRSize(20),
                  context.getRSize(20) + context.bottomInset,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: context.getRSize(14),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: _subtext,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.getRSize(12)),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueMain,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: context.getRSize(14),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? SizedBox(
                                width: context.getRSize(14),
                                height: context.getRSize(14),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                FontAwesomeIcons.check,
                                size: context.getRSize(14),
                              ),
                        label: Text(
                          _saving ? 'Saving...' : 'Confirm Returns',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: context.getRFontSize(14),
                          ),
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
    );
  }
}

class _CrateGroupRow {
  final int crateGroupId;
  final String name;
  final int expectedQty;
  final TextEditingController controller;

  _CrateGroupRow({
    required this.crateGroupId,
    required this.name,
    required this.expectedQty,
    required this.controller,
  });
}

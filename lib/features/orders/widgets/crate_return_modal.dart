import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/pin_dialog.dart';

class CrateReturnModal extends StatefulWidget {
  final OrderWithItems orderWithItems;

  const CrateReturnModal({super.key, required this.orderWithItems});

  /// Opens the modal only when appropriate:
  ///   - There must be glass (crate-group) items in the order.
  ///   - If the deposit already fully covers the expected crate deposit, skip.
  static Future<void> show(
    BuildContext context,
    OrderWithItems orderWithItems,
  ) async {
    // Guard 1: skip if no glass items
    final hasGlass = orderWithItems.items.any((i) => i.product.crateGroupId != null);
    if (!hasGlass) return;

    // Guard 2: skip if full deposit was already paid
    final allGroups = await database.inventoryDao.getAllCrateGroups();
    final groupDepositMap = {for (final g in allGroups) g.id: g.depositAmountKobo};
    int expectedDepositKobo = 0;
    for (final ri in orderWithItems.items) {
      final cgId = ri.product.crateGroupId;
      if (cgId != null) {
        expectedDepositKobo += (groupDepositMap[cgId] ?? 0) * ri.item.quantity;
      }
    }
    final paidDepositKobo = orderWithItems.order.crateDepositPaidKobo;
    if (expectedDepositKobo > 0 && paidDepositKobo >= expectedDepositKobo) return;

    if (!context.mounted) return;
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
  // True when a staff user confirmed with a short return — pending manager review
  bool _sentToManager = false;

  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _subtext =>
      Theme.of(context).textTheme.bodySmall?.color ??
      Theme.of(context).iconTheme.color!;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _border => Theme.of(context).dividerColor;

  @override
  void initState() {
    super.initState();
    _buildGroups();
  }

  Future<void> _buildGroups() async {
    final Map<int, int> groupQtys = {};
    for (final richItem in widget.orderWithItems.items) {
      final cgId = richItem.product.crateGroupId;
      if (cgId != null) {
        groupQtys[cgId] = (groupQtys[cgId] ?? 0) + richItem.item.quantity;
      }
    }

    final allGroups = await database.inventoryDao.getAllCrateGroups();
    final groupMap = {for (final g in allGroups) g.id: g};

    final rows = groupQtys.entries.map((entry) {
      final group = groupMap[entry.key];
      return _CrateGroupRow(
        crateGroupId: entry.key,
        name: group?.name ?? 'Group ${entry.key}',
        expectedQty: entry.value,
        depositAmountKobo: group?.depositAmountKobo ?? 0,
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
    if (_saving || _sentToManager) return;
    setState(() => _saving = true);

    final customer = widget.orderWithItems.customer;
    if (customer == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final order = widget.orderWithItems.order;
    final myTier = authService.currentUser?.roleTier ?? 1;
    bool hasShortReturn = false;

    for (final row in _groups) {
      final entered = int.tryParse(row.controller.text) ?? row.expectedQty;
      if (entered < row.expectedQty) {
        hasShortReturn = true;
        break;
      }
    }

    if (hasShortReturn) {
      if (myTier < 4) {
        // Staff: flag as pending for manager review
        await database.notificationsDao.create(
          'warning',
          'Short crate return on Order #${order.id} — pending manager review.',
          linkedRecordId: order.id.toString(),
        );

        // Save actual returned quantities even for short returns (track what was returned)
        for (final row in _groups) {
          final entered = int.tryParse(row.controller.text) ?? row.expectedQty;
          await database.customersDao.recordCrateReturn(
            customer.id,
            row.crateGroupId,
            entered,
          );
        }

        if (mounted) {
          setState(() {
            _saving = false;
            _sentToManager = true;
          });
          // Brief pause so the user sees the "Sent to Manager" state
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) Navigator.pop(context);
        }
        return;
      } else {
        // Manager/CEO: require PIN authorisation for short return
        if (!mounted) return;
        final approver = await PinDialog.show(
          context,
          minimumTier: 4,
          title: 'Manager Authorisation — Short Return',
        );
        if (approver == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
    }

    // Save all groups
    for (final row in _groups) {
      final entered = int.tryParse(row.controller.text) ?? row.expectedQty;
      await database.customersDao.recordCrateReturn(
        customer.id,
        row.crateGroupId,
        entered,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const amber = Color(0xFFF5A623);

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
                                              BorderSide(color: primary),
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
                        onPressed: (_saving || _sentToManager)
                            ? null
                            : () => Navigator.pop(context),
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
                        onPressed: (_saving || _sentToManager) ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _sentToManager ? amber : primary,
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
                                _sentToManager
                                    ? FontAwesomeIcons.clockRotateLeft
                                    : FontAwesomeIcons.check,
                                size: context.getRSize(14),
                              ),
                        label: Text(
                          _sentToManager
                              ? 'Sent to Manager'
                              : (_saving ? 'Saving...' : 'Confirm Returns'),
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
  final int depositAmountKobo;
  final TextEditingController controller;

  _CrateGroupRow({
    required this.crateGroupId,
    required this.name,
    required this.expectedQty,
    required this.depositAmountKobo,
    required this.controller,
  });
}

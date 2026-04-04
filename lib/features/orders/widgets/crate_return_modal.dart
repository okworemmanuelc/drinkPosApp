import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/pin_dialog.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/widgets/app_input.dart';

class CrateReturnModal extends StatefulWidget {
  final OrderWithItems orderWithItems;

  const CrateReturnModal({super.key, required this.orderWithItems});

  /// Opens the modal only when appropriate:
  ///   - There must be crate-group items in the order.
  ///   - If the deposit already fully covers the expected crate deposit, skip.
  static Future<void> show(
    BuildContext context,
    OrderWithItems orderWithItems,
  ) async {
    // Guard 1: skip if no crate items
    final hasCrates = orderWithItems.items.any(
      (i) => i.product.crateGroupId != null,
    );
    if (!hasCrates) return;

    // Guard 2: skip if full deposit was already paid
    final allGroups = await database.inventoryDao.getAllCrateGroups();
    final groupDepositMap = {
      for (final g in allGroups) g.id: g.depositAmountKobo,
    };
    int expectedDepositKobo = 0;
    for (final ri in orderWithItems.items) {
      final cgId = ri.product.crateGroupId;
      if (cgId != null) {
        expectedDepositKobo += (groupDepositMap[cgId] ?? 0) * ri.item.quantity;
      }
    }
    final paidDepositKobo = orderWithItems.order.crateDepositPaidKobo;
    if (expectedDepositKobo > 0 && paidDepositKobo >= expectedDepositKobo)
      return;

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
  List<_ManufacturerRow> _rows = [];
  bool _loading = true;
  bool _saving = false;
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
    _buildRows();
  }

  Future<void> _buildRows() async {
    // Accumulate: manufacturerId → {name, total qty, cgBreakdown}
    final Map<int, _ManufacturerAccum> accum = {};

    for (final ri in widget.orderWithItems.items) {
      final product = ri.product;
      if (product.crateGroupId == null) continue; // skip non-crate items

      final mfId = product.manufacturerId ?? 0;
      final mfName =
          product.manufacturer ??
          (mfId == 0 ? 'Unknown Manufacturer' : 'Manufacturer $mfId');
      final cgId = product.crateGroupId!;
      final qty = ri.item.quantity;

      accum.putIfAbsent(mfId, () => _ManufacturerAccum(id: mfId, name: mfName));
      accum[mfId]!.totalQty += qty;
      accum[mfId]!.cgBreakdown[cgId] =
          (accum[mfId]!.cgBreakdown[cgId] ?? 0) + qty;
    }

    final rows = accum.values
        .map(
          (a) => _ManufacturerRow(
            manufacturerId: a.id,
            name: a.name,
            expectedQty: a.totalQty,
            cgBreakdown: Map.unmodifiable(a.cgBreakdown),
            controller: TextEditingController(text: a.totalQty.toString()),
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving || _sentToManager) return;
    setState(() => _saving = true);

    final customer = widget.orderWithItems.customer;
    final order = widget.orderWithItems.order;
    final myTier = authService.currentUser?.roleTier ?? 1;
    bool hasShortReturn = false;

    for (final row in _rows) {
      final entered = int.tryParse(row.controller.text) ?? row.expectedQty;
      if (entered < row.expectedQty) {
        hasShortReturn = true;
        break;
      }
    }

    // Walk-in customer: short returns require manager PIN override
    if (customer == null) {
      if (hasShortReturn) {
        setState(() => _saving = false);
        if (!mounted) return;
        AppNotification.showError(
          context,
          'Walk-in customers must return all crates. A manager can override this.',
        );
        final approver = await PinDialog.show(
          context,
          minimumTier: 4,
          title: 'Manager Override — Short Return',
        );
        if (approver == null) return;
      }
      // Update physical crate stock for walk-in
      for (final row in _rows) {
        final returned = int.tryParse(row.controller.text) ?? row.expectedQty;
        if (row.manufacturerId != 0) {
          await database.inventoryDao.addEmptyCrates(
            row.manufacturerId,
            returned,
          );
        }
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    if (hasShortReturn && myTier < 4) {
      // Staff: save to pending queue and notify manager
      final returnData = _rows.map((row) {
        final entered = int.tryParse(row.controller.text) ?? row.expectedQty;
        return {
          'manufacturerId': row.manufacturerId,
          'manufacturerName': row.name,
          'expectedQty': row.expectedQty,
          'returnedQty': entered,
          'cgBreakdown': row.cgBreakdown.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
        };
      }).toList();

      final pendingId = await database.pendingCrateReturnsDao
          .createPendingReturn(
            orderId: order.id,
            customerId: customer.id,
            staffId: authService.currentUser!.id,
            returnDataJson: jsonEncode(returnData),
          );

      await database.notificationsDao.create(
        'crate_short_return',
        'Short crate return on Order #${order.id} by ${authService.currentUser?.name ?? 'staff'} — awaiting your approval.',
        linkedRecordId: pendingId.toString(),
      );

      if (mounted) {
        setState(() {
          _saving = false;
          _sentToManager = true;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    // Manager/CEO or no short return — save directly

    for (final row in _rows) {
      final returned = int.tryParse(row.controller.text) ?? row.expectedQty;
      // 1. Update physical crate stock on the Manufacturers table
      if (row.manufacturerId != 0) {
        await database.inventoryDao.addEmptyCrates(
          row.manufacturerId,
          returned,
        );
      }
      // 2. Record customer crate balance per crate group (proportional distribution)
      _distributeAndRecord(customer.id, row, returned);
    }

    if (mounted) Navigator.pop(context);
  }

  /// Distributes [returnedQty] across the crate groups of [row] proportionally
  /// and calls recordCrateReturn for each.
  void _distributeAndRecord(
    int customerId,
    _ManufacturerRow row,
    int returnedQty,
  ) {
    if (row.cgBreakdown.isEmpty) return;
    final entries = row.cgBreakdown.entries.toList();
    int remaining = returnedQty;
    for (int i = 0; i < entries.length; i++) {
      final cgId = entries[i].key;
      final cgExpected = entries[i].value;
      final cgReturned = i == entries.length - 1
          ? remaining
          : (returnedQty * cgExpected / row.expectedQty).round();
      remaining -= cgReturned;
      database.customersDao.recordCrateReturn(customerId, cgId, cgReturned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // amber unused after AppButton migration

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
              SizedBox(height: context.getRSize(4)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.getRSize(20)),
                child: Text(
                  'Enter returned crates per manufacturer.',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: context.getRFontSize(13),
                  ),
                ),
              ),
              SizedBox(height: context.getRSize(14)),
              Divider(height: 1, color: _border),

              // Manufacturer rows
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: EdgeInsets.all(context.getRSize(20)),
                        children: [
                          for (final row in _rows)
                            _ManufacturerReturnTile(
                              row: row,
                              card: _card,
                              border: _border,
                              text: _text,
                              subtext: _subtext,
                              primary: primary,
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
                      child: AppButton(
                        text: 'Skip',
                        variant: AppButtonVariant.ghost,
                        onPressed: (_saving || _sentToManager)
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: context.getRSize(12)),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: _sentToManager
                            ? 'Sent to Manager'
                            : (_saving ? 'Saving...' : 'Confirm Returns'),
                        icon: _sentToManager
                            ? FontAwesomeIcons.clockRotateLeft
                            : FontAwesomeIcons.check,
                        variant: _sentToManager
                            ? AppButtonVariant.secondary
                            : AppButtonVariant.primary,
                        isLoading: _saving,
                        onPressed: (_saving || _sentToManager)
                            ? null
                            : _confirm,
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

// ── Tile widget ────────────────────────────────────────────────────────────

class _ManufacturerReturnTile extends StatelessWidget {
  final _ManufacturerRow row;
  final Color card, border, text, subtext, primary;

  const _ManufacturerReturnTile({
    required this.row,
    required this.card,
    required this.border,
    required this.text,
    required this.subtext,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(12)),
      padding: EdgeInsets.all(context.getRSize(14)),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // Manufacturer icon badge
          Container(
            width: context.getRSize(40),
            height: context.getRSize(40),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              FontAwesomeIcons.industry,
              size: context.getRSize(16),
              color: const Color(0xFFF5A623),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                  ),
                ),
                SizedBox(height: context.getRSize(2)),
                Text(
                  'Expected: ${row.expectedQty} crate${row.expectedQty == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: subtext,
                    fontSize: context.getRFontSize(12),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: context.getRSize(80),
            child: AppInput(
              controller: row.controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              contentPadding: EdgeInsets.symmetric(
                vertical: context.getRSize(10),
                horizontal: context.getRSize(8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              fillColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────

class _ManufacturerRow {
  final int manufacturerId;
  final String name;
  final int expectedQty;
  final Map<int, int> cgBreakdown; // crateGroupId → expected qty
  final TextEditingController controller;

  _ManufacturerRow({
    required this.manufacturerId,
    required this.name,
    required this.expectedQty,
    required this.cgBreakdown,
    required this.controller,
  });
}

class _ManufacturerAccum {
  final int id;
  final String name;
  int totalQty = 0;
  Map<int, int> cgBreakdown = {};

  _ManufacturerAccum({required this.id, required this.name});
}

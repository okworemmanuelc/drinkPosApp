import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';

class CrateReturnApprovalScreen extends StatefulWidget {
  final int pendingReturnId;
  final int notificationId;

  const CrateReturnApprovalScreen({
    super.key,
    required this.pendingReturnId,
    required this.notificationId,
  });

  @override
  State<CrateReturnApprovalScreen> createState() =>
      _CrateReturnApprovalScreenState();
}

class _CrateReturnApprovalScreenState
    extends State<CrateReturnApprovalScreen> {
  PendingCrateReturnData? _record;
  CustomerData? _customer;
  UserData? _staff;
  OrderData? _order;
  List<Map<String, dynamic>> _returnData = [];
  bool _contentReady = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final record =
        await database.pendingCrateReturnsDao.getById(widget.pendingReturnId);
    if (record == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final customer =
        await database.customersDao.findById(record.customerId);
    final staff =
        await database.warehousesDao.getUserById(record.staffId);
    final order = await database.ordersDao.findById(record.orderId);

    final List<dynamic> raw = jsonDecode(record.returnDataJson);
    final returnData = raw.cast<Map<String, dynamic>>();

    if (mounted) {
      setState(() {
        _record = record;
        _customer = customer;
        _staff = staff;
        _order = order;
        _returnData = returnData;
        _contentReady = true;
      });
    }
  }

  Future<void> _approve() async {
    if (_saving || _record == null) return;
    setState(() => _saving = true);

    for (final row in _returnData) {
      final manufacturerId = row['manufacturerId'] as int? ?? 0;
      final returnedQty = row['returnedQty'] as int;
      final expectedQty = row['expectedQty'] as int;

      // 1. Add to physical crate stock on the Manufacturers table
      if (manufacturerId != 0) {
        await database.inventoryDao.addEmptyCrates(manufacturerId, returnedQty);
      }

      // 2. Distribute returned qty across crate groups proportionally for customer balance
      final cgBreakdownRaw = row['cgBreakdown'] as Map<String, dynamic>? ?? {};
      if (cgBreakdownRaw.isNotEmpty && expectedQty > 0) {
        final entries = cgBreakdownRaw.entries.toList();
        int remaining = returnedQty;
        for (int i = 0; i < entries.length; i++) {
          final cgId = int.tryParse(entries[i].key) ?? 0;
          final cgExpected = entries[i].value as int;
          final cgReturned = i == entries.length - 1
              ? remaining
              : (returnedQty * cgExpected / expectedQty).round();
          remaining -= cgReturned;
          if (cgId != 0) {
            await database.customersDao.recordCrateReturn(
                _record!.customerId, cgId, cgReturned);
          }
        }
      }
    }

    await database.pendingCrateReturnsDao.updateStatus(_record!.id, 'approved');
    await database.notificationsDao.markRead(widget.notificationId);
    await database.notificationsDao.create(
      'crate_return_approved',
      'Your crate return for Order #${_record!.orderId} has been approved.',
      linkedRecordId: _record!.id.toString(),
    );

    if (mounted) {
      Navigator.pop(context);
      AppNotification.showSuccess(context, 'Crate return approved.');
    }
  }

  Future<void> _reject() async {
    if (_saving || _record == null) return;
    setState(() => _saving = true);

    await database.pendingCrateReturnsDao.updateStatus(_record!.id, 'rejected');
    await database.notificationsDao.markRead(widget.notificationId);
    await database.notificationsDao.create(
      'crate_return_rejected',
      'Your crate return for Order #${_record!.orderId} was rejected by manager.',
      linkedRecordId: _record!.id.toString(),
    );

    if (mounted) {
      Navigator.pop(context);
      AppNotification.showSuccess(context, 'Crate return rejected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final text = Theme.of(context).colorScheme.onSurface;
    final subtext = Theme.of(context).textTheme.bodySmall?.color ??
        Theme.of(context).iconTheme.color!;
    final card = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    final primary = Theme.of(context).colorScheme.primary;
    const amber = Color(0xFFF5A623);
    // danger and success unused after AppButton migration
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FontAwesomeIcons.arrowLeft,
              size: context.getRSize(16), color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crate Return Approval',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: context.getRFontSize(17),
          ),
        ),
      ),
      body: _contentReady
          ? Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(context.getRSize(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info card
                        _InfoCard(
                          customer: _customer,
                          order: _order,
                          staff: _staff,
                          record: _record!,
                          card: card,
                          border: border,
                          text: text,
                          subtext: subtext,
                        ),
                        SizedBox(height: context.getRSize(24)),
                        Text(
                          'Return Details',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: context.getRFontSize(15),
                          ),
                        ),
                        SizedBox(height: context.getRSize(12)),
                        ..._returnData.map((row) => _CrateGroupRow(
                              row: row,
                              card: card,
                              border: border,
                              text: text,
                              subtext: subtext,
                              amber: amber,
                            )),
                        SizedBox(height: context.getRSize(16)),
                        _ShortageSummary(
                          returnData: _returnData,
                          card: card,
                          border: border,
                          text: text,
                          subtext: subtext,
                          amber: amber,
                        ),
                        SizedBox(height: context.getRSize(12)),
                      ],
                    ),
                  ),
                ),
                // Bottom action buttons
                Container(
                  padding: EdgeInsets.fromLTRB(
                    context.getRSize(20),
                    context.getRSize(12),
                    context.getRSize(20),
                    context.getRSize(20) + bottomInset,
                  ),
                  decoration: BoxDecoration(
                    color: card,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Reject',
                          icon: FontAwesomeIcons.xmark,
                          variant: AppButtonVariant.danger,
                          isLoading: _saving,
                          onPressed: _saving ? null : _reject,
                        ),
                      ),
                      SizedBox(width: context.getRSize(12)),
                      Expanded(
                        child: AppButton(
                          text: _saving ? 'Saving...' : 'Approve',
                          icon: FontAwesomeIcons.check,
                          isLoading: _saving,
                          onPressed: _saving ? null : _approve,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: CircularProgressIndicator(color: primary),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final CustomerData? customer;
  final OrderData? order;
  final UserData? staff;
  final PendingCrateReturnData record;
  final Color card, border, text, subtext;

  const _InfoCard({
    required this.customer,
    required this.order,
    required this.staff,
    required this.record,
    required this.card,
    required this.border,
    required this.text,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy – h:mm a').format(record.createdAt);
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.all(context.getRSize(16)),
      child: Column(
        children: [
          _row(context, 'Customer', customer?.name ?? 'Unknown'),
          _row(context, 'Order #', order?.id.toString() ?? record.orderId.toString()),
          _row(context, 'Submitted by', staff?.name ?? 'Unknown'),
          _row(context, 'Date', dateStr, isLast: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: context.getRSize(8)),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: subtext, fontSize: context.getRFontSize(13))),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w600,
                      fontSize: context.getRFontSize(13))),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: border),
      ],
    );
  }
}

class _CrateGroupRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final Color card, border, text, subtext, amber;

  const _CrateGroupRow({
    required this.row,
    required this.card,
    required this.border,
    required this.text,
    required this.subtext,
    required this.amber,
  });

  @override
  Widget build(BuildContext context) {
    final expected = row['expectedQty'] as int;
    final returned = row['returnedQty'] as int;
    final isShort = returned < expected;

    return Container(
      margin: EdgeInsets.only(bottom: context.getRSize(10)),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isShort ? amber.withValues(alpha: 0.4) : border),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: context.getRSize(16), vertical: context.getRSize(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (row['manufacturerName'] ?? row['crateGroupName'] ?? 'Unknown') as String,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                  ),
                ),
                SizedBox(height: context.getRSize(4)),
                Text(
                  'Expected: $expected',
                  style: TextStyle(
                      color: subtext, fontSize: context.getRFontSize(12)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$returned',
                style: TextStyle(
                  color: isShort ? amber : const Color(0xFF22C55E),
                  fontWeight: FontWeight.bold,
                  fontSize: context.getRFontSize(22),
                ),
              ),
              Text(
                'returned',
                style: TextStyle(
                    color: subtext, fontSize: context.getRFontSize(11)),
              ),
            ],
          ),
          if (isShort) ...[
            SizedBox(width: context.getRSize(8)),
            Icon(FontAwesomeIcons.triangleExclamation,
                color: amber, size: context.getRSize(16)),
          ],
        ],
      ),
    );
  }
}

class _ShortageSummary extends StatelessWidget {
  final List<Map<String, dynamic>> returnData;
  final Color card, border, text, subtext, amber;

  const _ShortageSummary({
    required this.returnData,
    required this.card,
    required this.border,
    required this.text,
    required this.subtext,
    required this.amber,
  });

  @override
  Widget build(BuildContext context) {
    int totalExpected = 0;
    int totalReturned = 0;
    int shortGroups = 0;

    for (final row in returnData) {
      final expected = row['expectedQty'] as int;
      final returned = row['returnedQty'] as int;
      totalExpected += expected;
      totalReturned += returned;
      if (returned < expected) shortGroups++;
    }

    final shortage = totalExpected - totalReturned;

    return Container(
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.3)),
      ),
      padding: EdgeInsets.all(context.getRSize(16)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.getRSize(10)),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(FontAwesomeIcons.boxOpen,
                color: amber, size: context.getRSize(18)),
          ),
          SizedBox(width: context.getRSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shortage Summary',
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: context.getRFontSize(14),
                  ),
                ),
                SizedBox(height: context.getRSize(4)),
                Text(
                  '$shortage crate${shortage == 1 ? '' : 's'} short across $shortGroups group${shortGroups == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: subtext, fontSize: context.getRFontSize(12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

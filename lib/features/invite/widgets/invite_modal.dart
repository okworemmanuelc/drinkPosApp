/// Two-step Add-Staff modal that replaces the new-staff branch of the old
/// `_StaffFormSheet`.
///
/// Step 1 — email
///   Client-side regex → POST `check-invite-email`. On `invite_pending`,
///   show inline "Resend?" CTA that fires `resend-invite` (the only path
///   that bypasses the pending check). On any other error, render the
///   per-code message inline. On `ok`, expand to step 2.
///
/// Step 2 — role + warehouse
///   AppDropdown for both, pinned email shown read-only at the top. CEO
///   is hidden (sender can't invite at that role). Submit → POST
///   `send-invite`. Server re-runs every check (defense in depth) and
///   returns `{invite_id, code, url, expires_at}`.
///
/// Step 3 — success
///   Show the URL, manual code, and three actions: Share (opens OS share
///   sheet via share_plus), Copy Link, Close. The modal stays mounted so
///   the admin can re-share repeatedly without re-issuing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/features/invite/services/invite_api_service.dart';
import 'package:reebaplus_pos/features/staff/screens/staff_constants.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/shared/widgets/app_dropdown.dart';

class InviteModal extends ConsumerStatefulWidget {
  final List<WarehouseData> warehouses;

  const InviteModal({super.key, required this.warehouses});

  @override
  ConsumerState<InviteModal> createState() => _InviteModalState();
}

enum _Phase { email, details, success }

class _InviteModalState extends ConsumerState<InviteModal> {
  _Phase _phase = _Phase.email;

  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _inlineError; // displayed under the email field
  String? _pendingInviteId; // when inline "Resend?" should be shown
  RoleOption _selectedRole =
      roleOptions.firstWhere((r) => r.value == 'cashier');
  String? _selectedWarehouseId;

  // Filled after successful send-invite / resend-invite.
  String? _resultCode;
  String? _resultUrl;
  DateTime? _resultExpiresAt;
  String? _resultEmail; // echo of the email used
  String _businessName = 'your business';

  @override
  void initState() {
    super.initState();
    if (widget.warehouses.isNotEmpty) {
      _selectedWarehouseId = widget.warehouses.first.id;
    }
    _loadBusinessName();
  }

  Future<void> _loadBusinessName() async {
    final auth = ref.read(authProvider);
    final db = ref.read(databaseProvider);
    final bizId = auth.value?.businessId;
    if (bizId == null) return;
    final biz = await (db.select(db.businesses)
          ..where((b) => b.id.equals(bizId))
          ..limit(1))
        .getSingleOrNull();
    if (mounted && biz != null) {
      setState(() => _businessName = biz.name);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinueFromEmail() async {
    final raw = _emailCtrl.text.trim().toLowerCase();
    if (!raw.contains('@') || !raw.contains('.')) {
      setState(() => _inlineError = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _busy = true;
      _inlineError = null;
      _pendingInviteId = null;
    });

    final api = ref.read(inviteApiServiceProvider);
    final result = await api.checkEmail(raw);

    if (!mounted) return;

    if (result is InviteApiErr<Map<String, dynamic>>) {
      final err = result;
      final pendingId = _extractPendingInviteId(err);
      setState(() {
        _busy = false;
        _inlineError = err.message;
        _pendingInviteId = pendingId;
      });
    } else {
      setState(() {
        _busy = false;
        _phase = _Phase.details;
      });
    }
  }

  static String? _extractPendingInviteId(
    InviteApiErr<Map<String, dynamic>> err,
  ) {
    if (err.code != InviteErrorCode.invitePending) return null;
    final details = err.details;
    if (details == null) return null;
    return details['invite_id']?.toString();
  }

  Future<void> _onResendFromInline() async {
    final inviteId = _pendingInviteId;
    if (inviteId == null) return;
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    final api = ref.read(inviteApiServiceProvider);
    final result = await api.resendInvite(inviteId);
    if (!mounted) return;
    _consumeIssueResult(result, _emailCtrl.text.trim().toLowerCase());
  }

  Future<void> _onSendFromDetails() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (_selectedWarehouseId == null) {
      setState(() => _inlineError = 'Pick a warehouse first.');
      return;
    }
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    final api = ref.read(inviteApiServiceProvider);
    final result = await api.sendInvite(
      email: email,
      role: _selectedRole.value,
      warehouseId: _selectedWarehouseId,
    );
    if (!mounted) return;
    _consumeIssueResult(result, email);
  }

  void _consumeIssueResult(
    InviteApiResult<Map<String, dynamic>> result,
    String email,
  ) {
    if (result is InviteApiErr<Map<String, dynamic>>) {
      final pendingId = _extractPendingInviteId(result);
      setState(() {
        _busy = false;
        _inlineError = result.message;
        _pendingInviteId = pendingId;
      });
      return;
    }
    final data = (result as InviteApiOk<Map<String, dynamic>>).data;
    setState(() {
      _busy = false;
      _phase = _Phase.success;
      _resultCode = data['code']?.toString();
      _resultUrl = data['url']?.toString();
      _resultExpiresAt =
          DateTime.tryParse(data['expires_at']?.toString() ?? '');
      _resultEmail = email;
    });
  }

  Future<void> _shareUrl() async {
    final url = _resultUrl;
    final code = _resultCode;
    if (url == null) return;
    final message = """You've been invited to join $_businessName on Reebaplus POS.

Tap to accept:
$url

Or open the app and enter this code:
$code

This link expires in 48 hours.""";
    await Share.share(message, subject: 'Reebaplus POS invite');
  }

  Future<void> _copyLink() async {
    final url = _resultUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_phase) {
          _Phase.email => _emailStep(),
          _Phase.details => _detailsStep(),
          _Phase.success => _successStep(),
        },
      ),
    );
  }

  List<Widget> _emailStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return [
      _header('Invite Staff', 'Enter the email of the person to invite.'),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDecorations.glassCard(context),
        child: TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _onContinueFromEmail(),
          style: TextStyle(color: textColor),
          decoration: AppDecorations.authInputDecoration(
            context,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
          ),
        ),
      ),
      if (_inlineError != null) ...[
        const SizedBox(height: 12),
        _inlineErrorBanner(),
      ],
      const SizedBox(height: 24),
      AppButton(
        text: 'Continue',
        isLoading: _busy && _pendingInviteId == null,
        onPressed: _busy ? null : _onContinueFromEmail,
      ),
    ];
  }

  List<Widget> _detailsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inviteRoles =
        roleOptions.where((r) => r.value != 'ceo').toList();
    return [
      _header('Invite Staff', 'Pick role and warehouse, then send.'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppDecorations.glassCard(context),
        child: Row(
          children: [
            Icon(Icons.email_outlined,
                size: 18, color: textColor.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _emailCtrl.text.trim(),
                style: TextStyle(color: textColor, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _phase = _Phase.email;
                        _inlineError = null;
                        _pendingInviteId = null;
                      }),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppDropdown<RoleOption>(
        labelText: 'Role & Access Level',
        value: _selectedRole.value == 'ceo' ? inviteRoles.last : _selectedRole,
        items: inviteRoles
            .map((r) => DropdownMenuItem<RoleOption>(
                  value: r,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: r.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                          child: Text(r.label, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (r) =>
            r == null ? null : setState(() => _selectedRole = r),
      ),
      const SizedBox(height: 12),
      AppDropdown<String>(
        labelText: 'Assigned Warehouse',
        value: _selectedWarehouseId,
        hintText: 'Select Warehouse',
        items: widget.warehouses
            .map((w) => DropdownMenuItem<String>(
                  value: w.id,
                  child: Text(w.name),
                ))
            .toList(),
        onChanged: (id) => setState(() => _selectedWarehouseId = id),
      ),
      if (_inlineError != null) ...[
        const SizedBox(height: 12),
        _inlineErrorBanner(),
      ],
      const SizedBox(height: 24),
      AppButton(
        text: 'Send Invitation',
        isLoading: _busy && _pendingInviteId == null,
        onPressed: _busy ? null : _onSendFromDetails,
      ),
    ];
  }

  List<Widget> _successStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final code = _resultCode ?? '';
    final email = _resultEmail ?? '';
    final hours =
        _resultExpiresAt?.difference(DateTime.now()).inHours.clamp(0, 9999);
    return [
      _header('Invitation ready',
          'Share this link with $email — they can join immediately.'),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.glassCard(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tag_rounded,
                    size: 18, color: textColor.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  'Manual code',
                  style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              code,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            if (hours != null)
              Text(
                'Expires in ${hours == 0 ? "<1" : hours} hour${hours == 1 ? "" : "s"}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppButton(text: 'Share invitation', onPressed: _shareUrl),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _copyLink,
        icon: const Icon(Icons.copy_rounded, size: 18),
        label: const Text('Copy link'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Done'),
      ),
    ];
  }

  Widget _header(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _inlineErrorBanner() {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _inlineError ?? '',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
          if (_pendingInviteId != null)
            TextButton(
              onPressed: _busy ? null : _onResendFromInline,
              child: const Text('Resend'),
            ),
        ],
      ),
    );
  }
}

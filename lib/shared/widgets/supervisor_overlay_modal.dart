import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../services/auth_service.dart';
import '../../features/auth/widgets/staff_selector.dart';
import '../../features/auth/widgets/pin_pad_view.dart';

class SupervisorOverlayModal extends StatefulWidget {
  final String reason;

  const SupervisorOverlayModal({super.key, required this.reason});

  static Future<bool> show(BuildContext context, String reason) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SupervisorOverlayModal(reason: reason),
    );
    return result ?? false;
  }

  @override
  State<SupervisorOverlayModal> createState() => _SupervisorOverlayModalState();
}

class _SupervisorOverlayModalState extends State<SupervisorOverlayModal> {
  UserData? _selectedSupervisor;
  List<UserData> _supervisors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSupervisors();
  }

  Future<void> _loadSupervisors() async {
    final list = await (database.select(database.users)
          ..where((t) => t.roleTier.isBiggerOrEqualValue(4)))
        .get();
    if (mounted) {
      setState(() {
        _supervisors = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        children: [
          // Header
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Manager Approval Required',
            style: context.h2.copyWith(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reason,
            textAlign: TextAlign.center,
            style: context.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _selectedSupervisor == null
                    ? SingleChildScrollView(
                        child: StaffSelector(
                          staffList: _supervisors,
                          onStaffSelected: (user) => setState(() => _selectedSupervisor = user),
                        ),
                      )
                    : PinPadView(
                        staff: _selectedSupervisor!,
                        onBack: () => setState(() => _selectedSupervisor = null),
                        onSuccess: () async {
                          final nav = Navigator.of(context);
                          // Log the action
                          await database.into(database.activityLogs).insert(
                                ActivityLogsCompanion.insert(
                                  userId: drift.Value(authService.currentUser?.id),
                                  action: 'Supervisor Overriden by ${_selectedSupervisor!.name} for: ${widget.reason}',
                                  description: 'Approval granted by supervisor ${_selectedSupervisor!.name} (ID: ${_selectedSupervisor!.id})',
                                  timestamp: drift.Value(DateTime.now()),
                                ),
                              );
                          nav.pop(true);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


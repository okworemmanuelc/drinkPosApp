import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';

import 'package:drift/drift.dart' as drift;

class AccessGrantedScreen extends StatefulWidget {
  final UserData user;

  const AccessGrantedScreen({super.key, required this.user});

  @override
  State<AccessGrantedScreen> createState() => _AccessGrantedScreenState();
}

class _AccessGrantedScreenState extends State<AccessGrantedScreen> {
  late Future<Map<String, String>> _futureDetails;

  @override
  void initState() {
    super.initState();
    _futureDetails = _fetchDetails();
  }

  Future<Map<String, String>> _fetchDetails() async {
    final res = {
      'businessName': '...',
      'locationName': '...',
      'inviterName': '...',
    };

    if (widget.user.businessId != null) {
      final biz = await (database.select(
        database.businesses,
      )..where((t) => t.id.equals(widget.user.businessId!))).getSingleOrNull();
      if (biz != null) res['businessName'] = biz.name;
    }

    if (widget.user.warehouseId != null) {
      final wh = await (database.select(
        database.warehouses,
      )..where((t) => t.id.equals(widget.user.warehouseId!))).getSingleOrNull();
      if (wh != null) res['locationName'] = wh.name;
    }

    if (widget.user.email != null) {
      final invite =
          await (database.select(database.invites)
                ..where((t) => t.email.equals(widget.user.email!))
                ..orderBy([
                  (t) => drift.OrderingTerm(
                    expression: t.usedAt,
                    mode: drift.OrderingMode.desc,
                  ),
                ]))
              .getSingleOrNull();

      if (invite != null) {
        final inviter = await (database.select(
          database.users,
        )..where((t) => t.id.equals(invite.createdBy))).getSingleOrNull();
        if (inviter != null) res['inviterName'] = inviter.name;
      }
    }

    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, String>>(
        future: _futureDetails,
        builder: (context, snapshot) {
          final details =
              snapshot.data ??
              {
                'businessName': '...',
                'locationName': '...',
                'inviterName': '...',
              };

          return Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: Image.asset(
                  'assets/images/auth_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 64,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(),
                              // Success Icon
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.how_to_reg_rounded,
                                    color: Colors.blueAccent,
                                    size: 80,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Success Text
                              const Center(
                                child: Text(
                                  'Access Granted!',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  'Welcome to the team, ${widget.user.name}. Here are your details:',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Info Cards
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildDetailRow(
                                          Icons.business_rounded,
                                          'Business',
                                          details['businessName']!,
                                        ),
                                        const Divider(
                                          color: Colors.white24,
                                          height: 32,
                                        ),
                                        _buildDetailRow(
                                          Icons.location_on_rounded,
                                          'Location',
                                          details['locationName']!,
                                        ),
                                        const Divider(
                                          color: Colors.white24,
                                          height: 32,
                                        ),
                                        _buildDetailRow(
                                          Icons.badge_rounded,
                                          'Role',
                                          widget.user.role.toUpperCase(),
                                        ),
                                        const Divider(
                                          color: Colors.white24,
                                          height: 32,
                                        ),
                                        _buildDetailRow(
                                          Icons.person_rounded,
                                          'Invited by',
                                          details['inviterName']!,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),
                              const SizedBox(height: 32),

                              AppButton(
                                text: 'Enter App',
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const MainLayout(),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

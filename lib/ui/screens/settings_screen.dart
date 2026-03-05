import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../widgets/bottom_nav_bar.dart';

/// Settings screen — user info, schema, sync, logs, logout.
/// Includes the bottom navigation bar (Settings tab active).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;
    final configGov = ref.read(configGovernanceProvider);
    final sync = ref.read(syncWorkerProvider);
    final queue = ref.read(offlineVoteQueueProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: -0.3,
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── User info ──
                  _SectionCard(
                    title: 'Account',
                    children: [
                      _InfoRow('Name', user?.name ?? '—'),
                      _InfoRow('Email', user?.email ?? '—'),
                      _InfoRow('Role', user?.role.name ?? '—'),
                      _InfoRow('Tenant', user?.tenantId ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Config ──
                  _SectionCard(
                    title: 'Configuration',
                    children: [
                      _InfoRow('Schema Version',
                          '${configGov.currentSchemaVersion}'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Sync ──
                  _SectionCard(
                    title: 'Sync Status',
                    children: [
                      _InfoRow(
                          'Worker running', sync.isRunning ? 'Yes' : 'No'),
                      _InfoRow('Offline queue', '${queue.length} votes'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Logs removed: kept settings minimal and privacy-friendly.

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        ref.read(syncWorkerProvider).stop();
                        await ref
                            .read(authStateProvider.notifier)
                            .logout();
                        if (context.mounted) context.go('/login');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Sign Out',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Bottom nav ──
            const AppBottomNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

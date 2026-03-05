import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../widgets/presence_indicator.dart';

/// Home screen — hub for navigation to dashboard, vote, presence, settings.
///
/// Relationships (C4):
///   Router → Presentation UI : navigates to in-app routes
///   UI     → PermissionsEngine : checks permissions
///   UI     → PresenceResolver  : resolves current building context
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final presence = ref.watch(presenceStateProvider);
    final perms = ref.read(permissionsEngineProvider);
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final canManage = presence.activeBuilding != null &&
        perms.canManageBuilding(user, presence.activeBuilding!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ComfortOS'),
        actions: [
          PresenceIndicator(presence: presence.presence),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notification list (simplified)
              final notifs = ref.read(notificationStateProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('${notifs.notifications.length} notifications')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User greeting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(user.name[0]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${user.name}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${user.role.name} · ${user.tenantId}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Active building info
          if (presence.activeBuilding != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.apartment),
                title: Text(presence.activeBuilding!.name),
                subtitle: Text(presence.activeBuilding!.address),
                trailing: IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () => context.go('/presence'),
                  tooltip: 'Change building',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
              color: Colors.orange[50],
              child: ListTile(
                leading: const Icon(Icons.location_off, color: Colors.orange),
                title: const Text('No building selected'),
                subtitle:
                    const Text('Set your building to access the dashboard'),
                trailing: ElevatedButton(
                  onPressed: () => context.go('/presence'),
                  child: const Text('Set'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Navigation tiles
          _NavTile(
            icon: Icons.dashboard,
            title: 'Dashboard',
            subtitle: 'View real-time building comfort data',
            enabled: presence.activeBuilding != null,
            onTap: () => context.go('/dashboard'),
          ),
          _NavTile(
            icon: Icons.how_to_vote,
            title: 'Vote',
            subtitle: 'Cast your comfort vote',
            enabled: presence.activeBuilding != null,
            onTap: () => context.go('/vote'),
          ),
          _NavTile(
            icon: Icons.location_on,
            title: 'Presence',
            subtitle: 'Manage your building presence',
            onTap: () => context.go('/presence'),
          ),
          if (canManage)
            _NavTile(
              icon: Icons.admin_panel_settings,
              title: 'Building Management',
              subtitle: 'Manage building configuration',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Management module coming soon')),
                );
              },
            ),
          _NavTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Account, schema info, logs',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon,
            color:
                enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

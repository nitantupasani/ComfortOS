import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

/// Presence management screen — building selection step.
///
/// Clean, minimal building picker. After selecting a building the user
/// proceeds to the Location screen (floor/room).
///
/// Flow: Login → **Presence** → Location → Dashboard
class PresenceScreen extends ConsumerWidget {
  const PresenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceStateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.apartment,
                    size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 24),

              const Text(
                'Select your\nbuilding',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the building you are currently in to get started.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),

              // Detection shortcuts
              Row(
                children: [
                  Expanded(
                    child: _DetectButton(
                      icon: Icons.wifi_find,
                      label: 'Auto-detect',
                      isLoading: presence.isScanning,
                      onTap: () => ref
                          .read(presenceStateProvider.notifier)
                          .autoDetect(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DetectButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR',
                      onTap: () => _showQRDialog(context, ref),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Divider with label
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[200])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or select manually',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ),
                  Expanded(child: Divider(color: Colors.grey[200])),
                ],
              ),

              const SizedBox(height: 16),

              // Building list
              Expanded(
                child: presence.availableBuildings.isEmpty
                    ? Center(
                        child: Text('No buildings loaded.',
                            style: TextStyle(color: Colors.grey[400])),
                      )
                    : ListView.separated(
                        itemCount: presence.availableBuildings.length,
                        separatorBuilder: (_, unused) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final building = presence.availableBuildings[i];
                          final isActive =
                              building.id == presence.activeBuilding?.id;
                          return GestureDetector(
                            onTap: () {
                              ref
                                  .read(presenceStateProvider.notifier)
                                  .manualSelect(building.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withAlpha(60)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade200,
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.apartment,
                                      color: isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.grey[600]),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(building.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            )),
                                        const SizedBox(height: 2),
                                        Text(building.address,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    Icon(Icons.check_circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (presence.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(presence.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              // Continue button
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: ElevatedButton(
                  onPressed: presence.activeBuilding != null
                      ? () => context.go('/location')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'bldg-001');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Simulate QR Scan'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'QR payload (building ID)',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(presenceStateProvider.notifier)
                  .scanQR(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }
}

class _DetectButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _DetectButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

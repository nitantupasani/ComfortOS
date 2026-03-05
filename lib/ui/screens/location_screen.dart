import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

/// Location resolver screen — selects floor & room within the active building.
///
/// SDUI-programmable: if the server provides a location form config (with
/// predefined floors and rooms), it renders dropdowns. Otherwise falls back
/// to manual text entry for floor number and room name.
///
/// Flow: Login → Presence (building) → **Location** → Dashboard
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  String? _selectedFloor;
  String? _selectedRoom;

  // Manual fallback controllers
  final _floorCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  @override
  void dispose() {
    _floorCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presence = ref.watch(presenceStateProvider);
    final building = presence.activeBuilding;
    final locationConfig = ref.watch(locationFormConfigProvider(
        building?.id ?? ''));

    if (building == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No building selected.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/presence'),
                child: const Text('Select Building'),
              ),
            ],
          ),
        ),
      );
    }

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
                child: Icon(Icons.location_on,
                    size: 32, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Where are you in\n${building.name}?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your floor and room so we can show you relevant comfort data.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Form — server-driven or manual
              Expanded(
                child: locationConfig.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => _buildManualForm(context),
                  data: (config) {
                    if (config == null) return _buildManualForm(context);
                    return _buildServerForm(context, config);
                  },
                ),
              ),

              // Continue button
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: ElevatedButton(
                  onPressed: _canContinue ? _continue : null,
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

  bool get _canContinue {
    // Server-driven: both dropdowns selected
    if (_selectedFloor != null && _selectedRoom != null) return true;
    // Manual: both fields filled
    if (_floorCtrl.text.trim().isNotEmpty && _roomCtrl.text.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  void _continue() {
    final floor = _selectedFloor ?? _floorCtrl.text.trim();
    final room = _selectedRoom ?? _roomCtrl.text.trim();
    ref.read(presenceStateProvider.notifier).setLocation(floor, room);
    context.go('/dashboard');
  }

  // ── Manual fallback form ──────────────────────────────────────────────

  Widget _buildManualForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Floor
        Text('Floor',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 6),
        TextField(
          controller: _floorCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 2',
            prefixIcon: const Icon(Icons.layers_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Room
        Text('Room',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 6),
        TextField(
          controller: _roomCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Conference Room A',
            prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ── Server-driven dropdown form ───────────────────────────────────────

  Widget _buildServerForm(
      BuildContext context, Map<String, dynamic> config) {
    final rawFloors = config['floors'] as List<dynamic>? ?? [];
    final floors = rawFloors.cast<Map<String, dynamic>>();
    final roomsByFloor = config['rooms'] as Map<String, dynamic>? ?? {};

    final currentRooms = _selectedFloor != null
        ? (roomsByFloor[_selectedFloor] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Floor',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFloor,
              hint: const Text('Select floor'),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: floors
                  .map((f) => DropdownMenuItem<String>(
                        value: f['value'] as String,
                        child: Text(f['label'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedFloor = v;
                _selectedRoom = null; // reset room when floor changes
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text('Room',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRoom,
              hint: Text(_selectedFloor == null
                  ? 'Select a floor first'
                  : 'Select room'),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: currentRooms
                  .map((r) => DropdownMenuItem<String>(
                        value: r['value'] as String,
                        child: Text(r['label'] as String),
                      ))
                  .toList(),
              onChanged: _selectedFloor == null
                  ? null
                  : (v) => setState(() => _selectedRoom = v),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/presence_state.dart';
import '../../state/providers.dart';
import '../sdui/sdui_renderer.dart';
import '../sdui/default_dashboard.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/shimmer_skeleton.dart';

/// Dashboard screen — renders SDUI config from ConfigGovernance.
/// Falls back to [DefaultDashboard] when no server config is received.
///
/// Integrates live weather from Open-Meteo and pre-caches the vote
/// form so navigation feels instant.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-cache vote form schema so it's ready when the user taps Vote.
    Future.microtask(() {
      final building = ref.read(presenceStateProvider).activeBuilding;
      if (building != null) {
        ref.read(voteFormConfigProvider(building.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final presence = ref.watch(presenceStateProvider);
    final building = presence.activeBuilding;

    if (building == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('Select a building first.')),
      );
    }

    final configAsync = ref.watch(dashboardConfigProvider(building.id));
    final weatherAsync = ref.watch(weatherProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Tappable location indicator
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          _showLocationSheet(context, ref, presence),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  building.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (presence.hasLocation)
                                  Text(
                                    'Floor ${presence.floor} · ${presence.room}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500]),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more,
                              size: 18, color: Colors.grey[500]),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(dashboardConfigProvider(building.id));
                      refreshWeather(ref);
                    },
                    child: Icon(Icons.refresh,
                        size: 20, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ──
            Expanded(
              child: configAsync.when(
                loading: () => const SingleChildScrollView(
                  child: DashboardSkeleton(),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (serverConfig) {
                  // Merge live weather into the SDUI config.
                  final config = _injectWeather(
                    serverConfig ?? DefaultDashboard.config,
                    weatherAsync,
                    building.city,
                    presence.room,
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(dashboardConfigProvider(building.id));
                      refreshWeather(ref);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: SDUIRenderer(config: config),
                    ),
                  );
                },
              ),
            ),

            // ── Vote CTA button ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/vote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.how_to_vote, size: 20),
                      SizedBox(width: 8),
                      Text('Vote on Comfort Level',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Bottom navigation ──
            const AppBottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  void _showLocationSheet(
      BuildContext context, WidgetRef ref, PresenceState presence) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationChangeSheet(currentPresence: presence),
    );
  }

  /// Walk the SDUI config tree and inject live weather data into any
  /// `weather_badge` node, and the selected room into any `room_selector`.
  /// This keeps the SDUI JSON simple while adding real-time data.
  Map<String, dynamic> _injectWeather(
    Map<String, dynamic> config,
    AsyncValue weatherAsync,
    String? city,
    String? room,
  ) {
    // Deep-copy so we don't mutate the cached config.
    final copy = _deepCopy(config);
    _walkAndPatch(copy, weatherAsync, city, room);
    return copy;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> src) {
    final result = <String, dynamic>{};
    for (final entry in src.entries) {
      if (entry.value is Map<String, dynamic>) {
        result[entry.key] = _deepCopy(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((e) {
          if (e is Map<String, dynamic>) return _deepCopy(e);
          return e;
        }).toList();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  void _walkAndPatch(
    Map<String, dynamic> node,
    AsyncValue weatherAsync,
    String? city,
    String? room,
  ) {
    final type = node['type'] as String?;

    if (type == 'weather_badge') {
      weatherAsync.whenData((weather) {
        if (weather != null) {
          node['temp'] = weather.tempDisplay;
          node['icon'] = weather.icon;
          node['label'] = city ?? 'Outside';
        }
      });
      // Use city name even before weather loads.
      if (city != null && node['label'] == 'Outside') {
        node['label'] = city;
      }
    }

    if (type == 'room_selector' && room != null) {
      node['room'] = room;
    }

    // Recurse into children.
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _walkAndPatch(child, weatherAsync, city, room);
        }
      }
    }
  }
}

// ── Location-change bottom sheet ─────────────────────────────────────────────

/// Modal bottom sheet that lets the user switch building and/or update their
/// floor/room without logging out.
class _LocationChangeSheet extends ConsumerStatefulWidget {
  final PresenceState currentPresence;

  const _LocationChangeSheet({required this.currentPresence});

  @override
  ConsumerState<_LocationChangeSheet> createState() =>
      _LocationChangeSheetState();
}

class _LocationChangeSheetState extends ConsumerState<_LocationChangeSheet> {
  late String? _selectedBuildingId;
  final _floorCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBuildingId = widget.currentPresence.activeBuilding?.id;
    _floorCtrl.text = widget.currentPresence.floor ?? '';
    _roomCtrl.text = widget.currentPresence.room ?? '';
  }

  @override
  void dispose() {
    _floorCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    return _selectedBuildingId != null &&
        _floorCtrl.text.trim().isNotEmpty &&
        _roomCtrl.text.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final notifier = ref.read(presenceStateProvider.notifier);
    final currentId = widget.currentPresence.activeBuilding?.id;

    // Switch building if it changed.
    if (_selectedBuildingId != currentId) {
      await notifier.manualSelect(_selectedBuildingId!);
      // Invalidate the old building's providers.
      if (currentId != null) {
        ref.invalidate(dashboardConfigProvider(currentId));
      }
    }

    notifier.setLocation(
      _floorCtrl.text.trim(),
      _roomCtrl.text.trim(),
    );

    // Refresh dashboard data for the (possibly new) building.
    ref.invalidate(dashboardConfigProvider(_selectedBuildingId!));
    // Clear weather cache and force a fresh API call for the new building.
    final weatherSvc = ref.read(weatherServiceProvider);
    weatherSvc.clearCache();
    ref.invalidate(weatherProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final presence = ref.watch(presenceStateProvider);
    final buildings = presence.availableBuildings;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Change Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch building or update your floor and room.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          // ── Building picker ──────────────────────────────────────────
          Text(
            'Building',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: buildings.isEmpty
                ? Text('No buildings available.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: buildings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final b = buildings[i];
                      final isSelected = b.id == _selectedBuildingId;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedBuildingId = b.id;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer.withAlpha(60)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.apartment,
                                size: 20,
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Text(b.address,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: colorScheme.primary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 20),

          // ── Floor / Room ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roomCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Conf A',
                        prefixIcon: const Icon(Icons.meeting_room_outlined,
                            size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Save button ──────────────────────────────────────────────
          ElevatedButton(
            onPressed: _canSave && !_saving ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

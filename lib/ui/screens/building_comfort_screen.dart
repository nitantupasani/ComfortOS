import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/building_comfort.dart';
import '../../state/providers.dart';
import '../sdui/sdui_renderer.dart';
import '../widgets/bottom_nav_bar.dart';

/// Building Comfort screen — shows aggregate comfort vote data for the
/// active building, broken down by floor and room.
///
/// Supports two rendering modes:
/// 1. **SDUI mode** — when the backend returns an `sduiConfig` in the
///    [BuildingComfortData] the screen renders it through [SDUIRenderer].
/// 2. **Default mode** — aesthetically categorises data by location
///    (floors → rooms) with animated score rings, breakdown bars, and
///    a building-wide summary header.
///
/// Navigated to automatically after a successful comfort vote.
class BuildingComfortScreen extends ConsumerStatefulWidget {
  const BuildingComfortScreen({super.key});

  @override
  ConsumerState<BuildingComfortScreen> createState() =>
      _BuildingComfortScreenState();
}

class _BuildingComfortScreenState extends ConsumerState<BuildingComfortScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presence = ref.watch(presenceStateProvider);
    final building = presence.activeBuilding;

    if (building == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Building Comfort')),
        body: const Center(child: Text('Select a building first.')),
      );
    }

    final comfortAsync = ref.watch(buildingComfortProvider(building.id));

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
                  Expanded(
                    child: Text(
                      'Building Comfort',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(buildingComfortProvider(building.id));
                    },
                    child: Icon(Icons.refresh,
                        size: 20, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: comfortAsync.when(
                loading: () => const _ComfortLoadingSkeleton(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Could not load comfort data',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text('$e',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400]),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  if (data == null) {
                    return _buildEmptyState();
                  }

                  // Kick off the score animation.
                  if (!_animCtrl.isCompleted) {
                    _animCtrl.forward();
                  }

                  // SDUI path — if the backend returned a custom layout.
                  if (data.sduiConfig != null) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                            buildingComfortProvider(building.id));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: SDUIRenderer(config: data.sduiConfig!),
                      ),
                    );
                  }

                  // Default aesthetic rendering.
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                          buildingComfortProvider(building.id));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _DefaultComfortView(
                        data: data,
                        animation: _scoreAnimation,
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Bottom navigation ──
            const AppBottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No comfort data yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Text(
              'Comfort scores will appear here once occupants start voting for this building.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DEFAULT COMFORT VIEW — floors → rooms breakdown
// ═══════════════════════════════════════════════════════════════════════════

class _DefaultComfortView extends StatelessWidget {
  final BuildingComfortData data;
  final Animation<double> animation;

  const _DefaultComfortView({
    required this.data,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Group locations by floor.
    final floorMap = <String, List<LocationComfortData>>{};
    for (final loc in data.locations) {
      floorMap.putIfAbsent(loc.floor, () => []).add(loc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Building summary header ──
        _OverallScoreCard(
          buildingName: data.buildingName,
          score: data.overallScore,
          totalVotes: data.totalVotes,
          computedAt: data.computedAt,
          animation: animation,
        ),
        const SizedBox(height: 20),

        // ── "Voted from" count ──
        _VoteSummaryChip(
          locationCount: data.locations.length,
          totalVotes: data.totalVotes,
        ),
        const SizedBox(height: 16),

        // ── Floor-by-floor breakdown ──
        ...floorMap.entries.map((entry) {
          final floorLabel = entry.value.first.floorLabel;
          return _FloorSection(
            floorLabel: floorLabel,
            rooms: entry.value,
            animation: animation,
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OVERALL SCORE CARD — animated ring + summary
// ═══════════════════════════════════════════════════════════════════════════

class _OverallScoreCard extends StatelessWidget {
  final String buildingName;
  final double score;
  final int totalVotes;
  final DateTime computedAt;
  final Animation<double> animation;

  const _OverallScoreCard({
    required this.buildingName,
    required this.score,
    required this.totalVotes,
    required this.computedAt,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _comfortColor(score);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withAlpha(15), scoreColor.withAlpha(40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            buildingName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // Animated ring
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: animation.value * (score / 10.0),
                    score: score * animation.value,
                    color: scoreColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          Text(
            _comfortLabel(score),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scoreColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalVotes total votes',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VOTE SUMMARY CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _VoteSummaryChip extends StatelessWidget {
  final int locationCount;
  final int totalVotes;

  const _VoteSummaryChip({
    required this.locationCount,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 18, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$totalVotes votes collected across $locationCount location${locationCount == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 13, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FLOOR SECTION — collapsible floor header + room cards
// ═══════════════════════════════════════════════════════════════════════════

class _FloorSection extends StatelessWidget {
  final String floorLabel;
  final List<LocationComfortData> rooms;
  final Animation<double> animation;

  const _FloorSection({
    required this.floorLabel,
    required this.rooms,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floor header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.layers, size: 16, color: Colors.grey[600]),
              ),
              const SizedBox(width: 10),
              Text(
                floorLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                '${rooms.length} zone${rooms.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),

        // Room cards
        ...rooms.map((room) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoomComfortCard(location: room, animation: animation),
            )),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROOM COMFORT CARD — individual score + breakdown bars
// ═══════════════════════════════════════════════════════════════════════════

class _RoomComfortCard extends StatelessWidget {
  final LocationComfortData location;
  final Animation<double> animation;

  const _RoomComfortCard({
    required this.location,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _comfortColor(location.comfortScore);
    final roomName = location.roomLabel ?? location.room ?? 'All Areas';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Room icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scoreColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.meeting_room_outlined,
                    size: 18, color: scoreColor),
              ),
              const SizedBox(width: 12),

              // Room name + vote count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${location.voteCount} vote${location.voteCount == 1 ? '' : 's'}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              // Score badge
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final displayScore =
                      location.comfortScore * animation.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${displayScore.toStringAsFixed(1)}/10',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Breakdown bars
          if (location.breakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...location.breakdown.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BreakdownBar(
                    label: _breakdownLabel(e.key),
                    value: e.value,
                    maxValue: 10,
                    animation: animation,
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BREAKDOWN BAR — animated fill for individual metrics
// ═══════════════════════════════════════════════════════════════════════════

class _BreakdownBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Animation<double> animation;

  const _BreakdownBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final animatedValue = value * animation.value;
        final fraction = (animatedValue / maxValue).clamp(0.0, 1.0);
        final barColor = _comfortColor(value);

        return Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(
                animatedValue.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOADING SKELETON — contextual shimmer while comfort data loads
// ═══════════════════════════════════════════════════════════════════════════

class _ComfortLoadingSkeleton extends StatelessWidget {
  const _ComfortLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loading message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading comfort data…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aggregating votes across all building locations',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Skeleton cards
          _SkeletonBox(height: 180), // score ring area
          const SizedBox(height: 16),
          _SkeletonBox(height: 42), // summary chip
          const SizedBox(height: 20),
          _SkeletonBox(height: 32, width: 140), // floor header
          const SizedBox(height: 10),
          _SkeletonBox(height: 120), // room card
          const SizedBox(height: 10),
          _SkeletonBox(height: 120), // room card
          const SizedBox(height: 20),
          _SkeletonBox(height: 32, width: 140), // floor header
          const SizedBox(height: 10),
          _SkeletonBox(height: 120), // room card
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;

  const _SkeletonBox({required this.height, this.width});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.06, end: 0.13).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCORE RING PAINTER — circular progress arc with centered score text
// ═══════════════════════════════════════════════════════════════════════════

class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final double score;
  final Color color;

  _ScoreRingPainter({
    required this.progress,
    required this.score,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring.
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc.
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from top
      2 * math.pi * progress,
      false,
      fgPaint,
    );

    // Score text.
    final textPainter = TextPainter(
      text: TextSpan(
        text: score.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2 + 4),
    );

    // "/10" text below score.
    final subPainter = TextPainter(
      text: TextSpan(
        text: '/10',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey[500],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(
      canvas,
      center - Offset(subPainter.width / 2, -textPainter.height / 2 + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress || old.score != score || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Color _comfortColor(double score) {
  if (score >= 8.0) return Colors.green.shade600;
  if (score >= 6.5) return Colors.teal.shade500;
  if (score >= 5.0) return Colors.orange.shade600;
  return Colors.red.shade500;
}

String _comfortLabel(double score) {
  if (score >= 8.5) return 'Excellent';
  if (score >= 7.0) return 'Good';
  if (score >= 5.5) return 'Fair';
  if (score >= 4.0) return 'Needs Improvement';
  return 'Poor';
}

String _breakdownLabel(String key) {
  switch (key) {
    case 'thermal':
      return 'Thermal';
    case 'air_quality':
      return 'Air Quality';
    case 'noise':
      return 'Noise';
    case 'lighting':
      return 'Lighting';
    case 'ventilation':
      return 'Ventilation';
    default:
      // Convert snake_case to Title Case.
      return key
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

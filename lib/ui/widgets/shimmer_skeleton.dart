import 'package:flutter/material.dart';

/// Lightweight animated shimmer placeholder used while data loads.
///
/// Shows a pulsing grey rounded rectangle — cleaner than a spinner and
/// gives the impression of fast, predictable loading.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 14,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.06, end: 0.14).animate(
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
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton layout mimicking the dashboard shape.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weather badge placeholder
          const ShimmerBox(width: 140, height: 34, borderRadius: 16),
          const SizedBox(height: 12),
          // Room title placeholder
          const ShimmerBox(width: 220, height: 30),
          const SizedBox(height: 20),
          // Metric grid row
          Row(
            children: [
              const Expanded(child: ShimmerBox(height: 90)),
              const SizedBox(width: 10),
              const Expanded(child: ShimmerBox(height: 90)),
              const SizedBox(width: 10),
              const Expanded(child: ShimmerBox(height: 90)),
            ],
          ),
          const SizedBox(height: 20),
          // Trend card placeholder
          const ShimmerBox(height: 200),
          const SizedBox(height: 20),
          // Alert banner placeholder
          const ShimmerBox(height: 72),
        ],
      ),
    );
  }
}

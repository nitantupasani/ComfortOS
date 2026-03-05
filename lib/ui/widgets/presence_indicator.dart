import 'package:flutter/material.dart';

import '../../domain/models/presence_info.dart';

/// Small visual indicator for the current presence method + confidence.
class PresenceIndicator extends StatelessWidget {
  final PresenceInfo? presence;

  const PresenceIndicator({super.key, required this.presence});

  @override
  Widget build(BuildContext context) {
    if (presence == null) {
      return Chip(
        avatar: const Icon(Icons.location_off, size: 18),
        label: const Text('No building'),
        backgroundColor: Colors.grey[200],
      );
    }

    final color = _confidenceColor(presence!.confidence);
    return Chip(
      avatar: Icon(_methodIcon(presence!.method), size: 18, color: color),
      label: Text(
        '${presence!.method.name.toUpperCase()} '
        '(${(presence!.confidence * 100).round()}%)',
      ),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  IconData _methodIcon(PresenceMethod method) {
    switch (method) {
      case PresenceMethod.qr:
        return Icons.qr_code_scanner;
      case PresenceMethod.wifi:
        return Icons.wifi;
      case PresenceMethod.ble:
        return Icons.bluetooth;
      case PresenceMethod.manual:
        return Icons.touch_app;
    }
  }

  Color _confidenceColor(double c) {
    if (c >= 0.8) return Colors.green;
    if (c >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

import 'package:flutter/material.dart';

import 'sdui_widget_registry.dart';

/// Server-Driven UI renderer: takes a JSON config tree and recursively
/// builds a Flutter widget tree.
///
/// Usage:
/// ```dart
/// SDUIRenderer(config: jsonMap)
/// ```
///
/// Relationships (C4):
///   Presentation UI renders dashboards via this component.
///   ConfigGovernance supplies the JSON config; when null the
///   DefaultDashboard constant is used as fallback.
class SDUIRenderer extends StatelessWidget {
  final Map<String, dynamic> config;

  const SDUIRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return _renderNode(config, context);
  }

  /// Recursive node renderer – delegates to [SDUIWidgetRegistry].
  static Widget _renderNode(Map<String, dynamic> node, BuildContext context) {
    final type = node['type'] as String? ?? 'unknown';
    return SDUIWidgetRegistry.build(type, node, context, _renderNode);
  }
}

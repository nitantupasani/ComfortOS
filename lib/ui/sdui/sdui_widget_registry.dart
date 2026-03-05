import 'package:flutter/material.dart';

import '../widgets/trend_chart_painter.dart';

/// Signature for a child-building callback passed into each SDUI builder.
typedef SDUIChildBuilder = Widget Function(
    Map<String, dynamic> node, BuildContext context);

/// Signature for an individual SDUI widget builder.
typedef SDUIBuilder = Widget Function(
  Map<String, dynamic> props,
  BuildContext context,
  SDUIChildBuilder childBuilder,
);

/// Registry of all SDUI widget types.
/// New types are added by inserting into [_builders].
class SDUIWidgetRegistry {
  SDUIWidgetRegistry._();

  static final Map<String, SDUIBuilder> _builders = {
    'column': _buildColumn,
    'row': _buildRow,
    'card': _buildCard,
    'text': _buildText,
    'metric': _buildMetric,
    'button': _buildButton,
    'spacer': _buildSpacer,
    'divider': _buildDivider,
    'padding': _buildPadding,
    'progress': _buildProgress,
    'sizedBox': _buildSizedBox,
    'container': _buildContainer,
    'chip': _buildChip,
    'icon': _buildIcon,
    // ── Dashboard-oriented widgets ────────────────────────────────────
    'weather_badge': _buildWeatherBadge,
    'room_selector': _buildRoomSelector,
    'metric_tile': _buildMetricTile,
    'trend_card': _buildTrendCard,
    'alert_banner': _buildAlertBanner,
    'primary_action': _buildPrimaryAction,
    'grid': _buildGrid,
    // ── Extended convenience widgets ──────────────────────────────────
    'section_header': _buildSectionHeader,
    'stat_row': _buildStatRow,
    'progress_bar': _buildProgressBar,
    'kpi_card': _buildKpiCard,
    'info_row': _buildInfoRow,
    'badge_row': _buildBadgeRow,
    'occupancy_indicator': _buildOccupancyIndicator,
    'schedule_item': _buildScheduleItem,
    'image_banner': _buildImageBanner,
  };

  /// Look up the builder for [type] and invoke it, or return a placeholder.
  static Widget build(
    String type,
    Map<String, dynamic> props,
    BuildContext context,
    SDUIChildBuilder childBuilder,
  ) {
    final builder = _builders[type];
    if (builder == null) {
      return const SizedBox.shrink();
    }
    return builder(props, context, childBuilder);
  }

  // ── Builder implementations ───────────────────────────────────────────

  static List<Widget> _children(
      Map<String, dynamic> props, BuildContext ctx, SDUIChildBuilder cb) {
    final raw = props['children'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((child) => cb(child, ctx))
        .toList();
  }

  static CrossAxisAlignment _crossAxis(String? value) {
    switch (value) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.center;
    }
  }

  static MainAxisAlignment _mainAxis(String? value) {
    switch (value) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  // -- Column
  static Widget _buildColumn(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    return Column(
      crossAxisAlignment:
          _crossAxis(p['crossAxisAlignment'] as String?),
      mainAxisAlignment:
          _mainAxis(p['mainAxisAlignment'] as String?),
      mainAxisSize: MainAxisSize.min,
      children: _children(p, ctx, cb),
    );
  }

  // -- Row
  static Widget _buildRow(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    return Row(
      mainAxisAlignment:
          _mainAxis(p['mainAxisAlignment'] as String?),
      crossAxisAlignment:
          _crossAxis(p['crossAxisAlignment'] as String?),
      children: _children(p, ctx, cb),
    );
  }

  // -- Card (material card with optional title)
  static Widget _buildCard(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final title = p['title'] as String?;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),
            ],
            ..._children(p, ctx, cb),
          ],
        ),
      ),
    );
  }

  // -- Text
  static Widget _buildText(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final text = p['text'] as String? ?? '';
    final styleName = p['style'] as String?;
    TextStyle? style;
    switch (styleName) {
      case 'headline':
        style = Theme.of(ctx).textTheme.headlineSmall;
        break;
      case 'title':
        style = Theme.of(ctx).textTheme.titleMedium;
        break;
      case 'caption':
        style = Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            );
        break;
      case 'body':
      default:
        style = Theme.of(ctx).textTheme.bodyMedium;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: style),
    );
  }

  // -- Metric (icon + label + value)
  static Widget _buildMetric(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? '';
    final value = p['value'] as String? ?? '';
    final iconName = p['icon'] as String? ?? 'info';
    final icon = _resolveIcon(iconName);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 28, color: Theme.of(ctx).colorScheme.primary),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  )),
        ],
      ),
    );
  }

  // -- Button
  static Widget _buildButton(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? 'Button';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: () {}, // SDUI buttons raise events in a full implementation
        child: Text(label),
      ),
    );
  }

  // -- Spacer
  static Widget _buildSpacer(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final height = (p['height'] as num?)?.toDouble() ?? 16;
    return SizedBox(height: height);
  }

  // -- Divider
  static Widget _buildDivider(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    return const Divider();
  }

  // -- Padding
  static Widget _buildPadding(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final all = (p['all'] as num?)?.toDouble() ?? 16;
    final kids = _children(p, ctx, cb);
    return Padding(
      padding: EdgeInsets.all(all),
      child: kids.length == 1 ? kids.first : Column(children: kids),
    );
  }

  // -- Progress indicator (linear)
  static Widget _buildProgress(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final value = (p['value'] as num?)?.toDouble() ?? 0;
    final label = p['label'] as String?;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label, style: Theme.of(ctx).textTheme.bodySmall),
        ],
      ],
    );
  }

  // -- SizedBox
  static Widget _buildSizedBox(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    return SizedBox(
      width: (p['width'] as num?)?.toDouble(),
      height: (p['height'] as num?)?.toDouble(),
    );
  }

  // -- Container
  static Widget _buildContainer(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final kids = _children(p, ctx, cb);
    return Container(
      padding: const EdgeInsets.all(8),
      child: kids.length == 1 ? kids.first : Column(children: kids),
    );
  }

  // -- Chip
  static Widget _buildChip(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? '';
    return Chip(label: Text(label));
  }

  // -- Icon
  static Widget _buildIcon(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final name = p['name'] as String? ?? 'info';
    final size = (p['size'] as num?)?.toDouble() ?? 24;
    return Icon(_resolveIcon(name), size: size);
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── NEW: Dashboard-oriented widget builders ─────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  // -- Weather badge (e.g. "15°C Outside")
  static Widget _buildWeatherBadge(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final temp = p['temp'] as String? ?? '--';
    final unit = p['unit'] as String? ?? '°C';
    final label = p['label'] as String? ?? 'Outside';
    final iconName = p['icon'] as String? ?? 'wb_sunny';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(ctx).colorScheme.primary.withAlpha(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_resolveIcon(iconName),
              size: 16, color: Theme.of(ctx).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$temp$unit $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(ctx).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // -- Room selector — hidden; location is shown in the dashboard top bar.
  static Widget _buildRoomSelector(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    return const SizedBox.shrink();
  }

  // -- Metric tile (compact card: icon + value + unit + label)
  static Widget _buildMetricTile(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final iconName = p['icon'] as String? ?? 'info';
    final value = p['value'] as String? ?? '--';
    final unit = p['unit'] as String? ?? '';
    final label = p['label'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_resolveIcon(iconName),
              size: 20, color: Theme.of(ctx).colorScheme.primary),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).textTheme.bodyLarge?.color,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // -- Trend card (title + subtitle + change badge + area chart)
  static Widget _buildTrendCard(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final title = p['title'] as String? ?? 'Trend';
    final subtitle = p['subtitle'] as String?;
    final change = p['change'] as String?;
    final rawData = p['data'] as List<dynamic>? ?? [];
    final data = rawData.map((e) => (e as num).toDouble()).toList();
    final rawLabels = p['labels'] as List<dynamic>? ?? [];
    final labels = rawLabels.cast<String>();

    final primaryColor = Theme.of(ctx).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ),
                ],
              ),
              if (change != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(change,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          )),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (data.isNotEmpty)
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: Size.infinite,
                painter: TrendChartPainter(
                  data: data,
                  lineColor: primaryColor,
                  fillColor: primaryColor,
                ),
              ),
            ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels
                  .map((l) => Text(l,
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // -- Alert banner (colored info/warning)
  static Widget _buildAlertBanner(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final iconName = p['icon'] as String? ?? 'info';
    final title = p['title'] as String? ?? '';
    final subtitle = p['subtitle'] as String?;
    final colorName = p['color'] as String? ?? 'blue';

    final colorMap = <String, Color>{
      'orange': Colors.orange,
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
      'amber': Colors.amber,
    };
    final color = colorMap[colorName] ?? Colors.blue;
    final bgColor = color.withAlpha(20);
    final borderColor = color.withAlpha(40);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(_resolveIcon(iconName), size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Primary action button (full-width prominent button)
  static Widget _buildPrimaryAction(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? 'Action';
    final iconName = p['icon'] as String?;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {}, // SDUI buttons raise events in full implementation
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(ctx).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconName != null) ...[
              Icon(_resolveIcon(iconName), size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // -- Grid layout (N-column responsive grid)
  static Widget _buildGrid(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final columns = (p['columns'] as num?)?.toInt() ?? 3;
    final spacing = (p['spacing'] as num?)?.toDouble() ?? 10;
    final kids = _children(p, ctx, cb);

    // Build rows of N columns
    final rows = <Widget>[];
    for (int i = 0; i < kids.length; i += columns) {
      final rowKids = <Widget>[];
      for (int j = i; j < i + columns; j++) {
        if (j < kids.length) {
          rowKids.add(Expanded(child: kids[j]));
        } else {
          rowKids.add(const Expanded(child: SizedBox.shrink()));
        }
        if (j < i + columns - 1) {
          rowKids.add(SizedBox(width: spacing));
        }
      }
      rows.add(Row(children: rowKids));
      if (i + columns < kids.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  // ── Icon name → IconData resolver ─────────────────────────────────────

  static IconData _resolveIcon(String name) {
    const map = <String, IconData>{
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'air': Icons.air,
      'volume_up': Icons.volume_up,
      'light_mode': Icons.light_mode,
      'bolt': Icons.bolt,
      'info': Icons.info_outline,
      'check': Icons.check_circle,
      'warning': Icons.warning,
      'error': Icons.error,
      'home': Icons.home,
      'person': Icons.person,
      'settings': Icons.settings,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'thumb_up': Icons.thumb_up,
      // Dashboard icons
      'wb_sunny': Icons.wb_sunny,
      'co2': Icons.co2,
      'device_thermostat': Icons.device_thermostat,
      'how_to_vote': Icons.how_to_vote,
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'cloud': Icons.cloud,
      'cloud_off': Icons.cloud_off,
      'ac_unit': Icons.ac_unit,
      'local_fire_department': Icons.local_fire_department,
      'visibility': Icons.visibility,
      'speed': Icons.speed,
      'eco': Icons.eco,
      // Extended icon set
      'people': Icons.people,
      'meeting_room': Icons.meeting_room,
      'schedule': Icons.schedule,
      'event': Icons.event,
      'wifi': Icons.wifi,
      'battery_full': Icons.battery_full,
      'battery_charging_full': Icons.battery_charging_full,
      'solar_power': Icons.solar_power,
      'energy_savings_leaf': Icons.energy_savings_leaf,
      'power': Icons.power,
      'wb_cloudy': Icons.wb_cloudy,
      'rainy': Icons.water_drop,
      'nights_stay': Icons.nights_stay,
      'wb_twilight': Icons.wb_twilight,
      'opacity': Icons.opacity,
      'water': Icons.water,
      'park': Icons.park,
      'fitness_center': Icons.fitness_center,
      'restaurant': Icons.restaurant,
      'local_parking': Icons.local_parking,
      'elevator': Icons.elevator,
      'stairs': Icons.stairs,
      'accessible': Icons.accessible,
      'cleaning_services': Icons.cleaning_services,
      'security': Icons.security,
      'verified': Icons.verified,
      'timer': Icons.timer,
      'update': Icons.update,
      'notifications': Icons.notifications,
      'campaign': Icons.campaign,
      'construction': Icons.construction,
      'handyman': Icons.handyman,
      'science': Icons.science,
      'biotech': Icons.biotech,
      'monitor_heart': Icons.monitor_heart,
      'health_and_safety': Icons.health_and_safety,
      'chair': Icons.chair,
      'desk': Icons.desk,
      'light': Icons.light,
      'lightbulb': Icons.lightbulb,
      'tungsten': Icons.tungsten,
      'wb_incandescent': Icons.wb_incandescent,
    };
    return map[name] ?? Icons.help_outline;
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Extended convenience widget builders ─────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  // -- Section Header (bold title + optional subtitle, used to delimit groups)
  static Widget _buildSectionHeader(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final title = p['title'] as String? ?? '';
    final subtitle = p['subtitle'] as String?;
    final iconName = p['icon'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          if (iconName != null) ...[
            Icon(_resolveIcon(iconName),
                size: 18, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Stat Row (label + value on a horizontal line, like "Occupancy: 73%")
  static Widget _buildStatRow(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? '';
    final value = p['value'] as String? ?? '';
    final iconName = p['icon'] as String?;
    final color = _resolveColor(p['color'] as String?);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (iconName != null) ...[
            Icon(_resolveIcon(iconName), size: 16, color: color ?? Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  // -- Progress Bar (labeled horizontal bar, e.g. air quality index, energy)
  static Widget _buildProgressBar(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? '';
    final value = (p['value'] as num?)?.toDouble() ?? 0;
    final maxVal = (p['max'] as num?)?.toDouble() ?? 100;
    final unit = p['unit'] as String? ?? '';
    final colorName = p['color'] as String?;
    final color = _resolveColor(colorName) ?? Theme.of(ctx).colorScheme.primary;
    final fraction = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              Text('${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}$unit',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // -- KPI Card (big number + label + optional trend icon, standalone card)
  static Widget _buildKpiCard(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final title = p['title'] as String? ?? '';
    final value = p['value'] as String? ?? '--';
    final unit = p['unit'] as String? ?? '';
    final trend = p['trend'] as String?; // 'up', 'down', or null
    final colorName = p['color'] as String?;
    final color = _resolveColor(colorName) ?? Theme.of(ctx).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600])),
              if (trend != null)
                Icon(
                  trend == 'up' ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: trend == 'up' ? Colors.green : Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // -- Info Row (key-value with icon, used in schedule/details cards)
  static Widget _buildInfoRow(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? '';
    final value = p['value'] as String? ?? '';
    final iconName = p['icon'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (iconName != null) ...[
            Icon(_resolveIcon(iconName), size: 16, color: Colors.grey[500]),
            const SizedBox(width: 10),
          ],
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // -- Badge Row (horizontal row of colored chips/badges)
  static Widget _buildBadgeRow(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final rawBadges = p['badges'] as List<dynamic>? ?? [];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: rawBadges.map((b) {
        final badge = b as Map<String, dynamic>;
        final label = badge['label'] as String? ?? '';
        final colorName = badge['color'] as String?;
        final iconName = badge['icon'] as String?;
        final color = _resolveColor(colorName) ?? Colors.blue;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconName != null) ...[
                Icon(_resolveIcon(iconName), size: 13, color: color),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -- Occupancy Indicator (circular percentage + label)
  static Widget _buildOccupancyIndicator(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final label = p['label'] as String? ?? 'Occupancy';
    final percent = (p['percent'] as num?)?.toDouble() ?? 0;
    final colorName = p['color'] as String?;
    final color = _resolveColor(colorName) ?? Theme.of(ctx).colorScheme.primary;
    final fraction = (percent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 5,
                  backgroundColor: Colors.grey[200],
                  color: color,
                ),
                Text('${percent.round()}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  percent >= 80
                      ? 'High utilisation'
                      : percent >= 40
                          ? 'Moderate'
                          : 'Low utilisation',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Schedule Item (time + title + optional subtitle, timeline style)
  static Widget _buildScheduleItem(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final time = p['time'] as String? ?? '';
    final title = p['title'] as String? ?? '';
    final subtitle = p['subtitle'] as String?;
    final iconName = p['icon'] as String? ?? 'event';
    final isActive = p['active'] as bool? ?? false;
    final color =
        isActive ? Theme.of(ctx).colorScheme.primary : Colors.grey[400]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(time,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Container(width: 2, height: 28, color: Colors.grey[200]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
              ],
            ),
          ),
          Icon(_resolveIcon(iconName), size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  // -- Image Banner (placeholder – renders a colored banner since we can't
  //    load arbitrary images inside a SDUI context without network access)
  static Widget _buildImageBanner(
      Map<String, dynamic> p, BuildContext ctx, SDUIChildBuilder cb) {
    final title = p['title'] as String? ?? '';
    final subtitle = p['subtitle'] as String?;
    final iconName = p['icon'] as String? ?? 'info';
    final colorName = p['color'] as String? ?? 'blue';
    final color = _resolveColor(colorName) ?? Colors.blue;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(180), color.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(200))),
                  ),
              ],
            ),
          ),
          Icon(_resolveIcon(iconName), size: 36, color: Colors.white.withAlpha(180)),
        ],
      ),
    );
  }

  // ── Color name → Color resolver ───────────────────────────────────────

  static Color? _resolveColor(String? name) {
    if (name == null) return null;
    const map = <String, Color>{
      'red': Colors.red,
      'orange': Colors.orange,
      'amber': Colors.amber,
      'green': Colors.green,
      'blue': Colors.blue,
      'indigo': Colors.indigo,
      'purple': Colors.purple,
      'teal': Colors.teal,
      'cyan': Colors.cyan,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'grey': Colors.grey,
    };
    return map[name];
  }
}

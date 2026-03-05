import 'package:flutter/material.dart';

/// Dynamic vote form widget rendered from a schema (SDUI vote form config).
///
/// Supports field types:
///   - `slider`             : standard slider (legacy)
///   - `thermal_scale`      : 7-point thermal comfort scale with color coding
///   - `single_select`      : radio-button-style option group (supports emoji/icon)
///   - `multi_select`       : multi-toggle chip group (supports emoji/icon, exclusive)
///   - `emoji_scale`        : horizontal row of large emoji buttons
///   - `emoji_single_select`: single-choice with big emoji + label cards
///   - `emoji_multi_select` : multi-choice with big emoji + label cards
///   - `rating_stars`       : star-rating (1–N)
///   - `text_input`         : freeform text area
///   - `yes_no`             : binary yes / no toggle
///
/// Schema structure (from server via facility-manager frontend):
/// ```json
/// {
///   "schemaVersion": 2,
///   "formTitle": "Comfort Vote",
///   "formDescription": "Quick 1-minute survey about your environment.",
///   "thanksMessage": "Thanks for your feedback!",
///   "allowAnonymous": false,
///   "cooldownMinutes": 30,
///   "fields": [ ... ]
/// }
/// ```
class VoteFormWidget extends StatefulWidget {
  final Map<String, dynamic>? formSchema;
  final void Function(Map<String, dynamic> payload) onSubmit;

  const VoteFormWidget({
    super.key,
    this.formSchema,
    required this.onSubmit,
  });

  @override
  State<VoteFormWidget> createState() => _VoteFormWidgetState();
}

class _VoteFormWidgetState extends State<VoteFormWidget> {
  final Map<String, dynamic> _values = {};

  List<Map<String, dynamic>> get _fields {
    final raw = widget.formSchema?['fields'] as List<dynamic>?;
    if (raw != null) return raw.cast<Map<String, dynamic>>();
    return _defaultFields;
  }

  static const _defaultFields = <Map<String, dynamic>>[
    {
      'key': 'thermal_comfort',
      'label': 'Thermal Comfort',
      'type': 'slider',
      'min': 1,
      'max': 7,
      'defaultValue': 4,
    },
    {
      'key': 'air_quality',
      'label': 'Air Quality',
      'type': 'slider',
      'min': 1,
      'max': 5,
      'defaultValue': 3,
    },
    {
      'key': 'overall',
      'label': 'Overall Satisfaction',
      'type': 'slider',
      'min': 1,
      'max': 5,
      'defaultValue': 3,
    },
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      final key = field['key'] as String;
      final type = field['type'] as String? ?? 'slider';
      switch (type) {
        case 'multi_select':
        case 'emoji_multi_select':
          _values[key] = <String>[];
          break;
        case 'text_input':
          _values[key] = '';
          break;
        case 'yes_no':
          _values[key] = null; // null = no selection yet
          break;
        default:
          _values[key] =
              (field['defaultValue'] as num?)?.toDouble() ?? 0.0;
      }
    }
  }

  bool get _isComplete {
    for (final field in _fields) {
      final key = field['key'] as String;
      final type = field['type'] as String? ?? 'slider';
      final required_ = field['required'] as bool? ?? true;
      if (!required_) continue;

      final val = _values[key];
      switch (type) {
        case 'thermal_scale':
        case 'single_select':
        case 'emoji_scale':
        case 'emoji_single_select':
        case 'rating_stars':
          if (val == null || val == 0.0) return false;
          break;
        case 'multi_select':
        case 'emoji_multi_select':
          final list = val as List<String>? ?? [];
          if (list.isEmpty) return false;
          break;
        case 'text_input':
          if (val == null || (val as String).trim().isEmpty) return false;
          break;
        case 'yes_no':
          if (val == null) return false;
          break;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final formTitle = widget.formSchema?['formTitle'] as String?;
    final formDesc = widget.formSchema?['formDescription'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formTitle != null) ...[
          Text(formTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[900])),
          const SizedBox(height: 4),
        ],
        if (formDesc != null) ...[
          Text(formDesc,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
        ],
        for (int i = 0; i < _fields.length; i++) ...[
          _buildField(_fields[i], context, i + 1),
          if (i < _fields.length - 1) const SizedBox(height: 28),
        ],
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isComplete ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
      Map<String, dynamic> field, BuildContext context, int index) {
    final type = field['type'] as String? ?? 'slider';
    switch (type) {
      case 'thermal_scale':
        return _buildThermalScale(field, context, index);
      case 'single_select':
        return _buildSingleSelect(field, context, index);
      case 'multi_select':
        return _buildMultiSelect(field, context, index);
      case 'emoji_scale':
        return _buildEmojiScale(field, context, index);
      case 'emoji_single_select':
        return _buildEmojiSingleSelect(field, context, index);
      case 'emoji_multi_select':
        return _buildEmojiMultiSelect(field, context, index);
      case 'rating_stars':
        return _buildRatingStars(field, context, index);
      case 'text_input':
        return _buildTextInput(field, context, index);
      case 'yes_no':
        return _buildYesNo(field, context, index);
      case 'slider':
      default:
        return _buildSlider(field, context, index);
    }
  }

  // ── Thermal scale (7-point colored circles) ───────────────────────────

  Widget _buildThermalScale(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Thermal Comfort';
    final min = (field['min'] as num?)?.toInt() ?? 1;
    final max = (field['max'] as num?)?.toInt() ?? 7;
    final labels = field['labels'] as Map<String, dynamic>? ?? {};
    final selected = (_values[key] as num?)?.toInt() ?? 0;

    // Color gradient from blue (cold) → green (neutral) → red (hot)
    final colors = _thermalColors(max - min + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index. $question',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.green[900],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(max - min + 1, (i) {
            final value = min + i;
            final isSelected = selected == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _values[key] = value.toDouble()),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors[i]
                        : colors[i].withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colors[i] : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : colors[i],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labels[min.toString()] ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text(labels[((min + max) ~/ 2).toString()] ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text(labels[max.toString()] ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ],
    );
  }

  List<Color> _thermalColors(int count) {
    // Blue → Teal → Green → Yellow → Orange → Red-orange → Red
    const palette = [
      Color(0xFF2196F3), // Cold — blue
      Color(0xFF00ACC1), // Cool — teal
      Color(0xFF26A69A), // Slightly cool — green-teal
      Color(0xFF4CAF50), // Neutral — green
      Color(0xFFFFC107), // Slightly warm — amber
      Color(0xFFFF9800), // Warm — orange
      Color(0xFFF44336), // Hot — red
    ];
    if (count <= palette.length) return palette.sublist(0, count);
    return List.generate(count, (i) => palette[i % palette.length]);
  }

  // ── Single-select button group (radio-like, supports emoji/icon) ────

  Widget _buildSingleSelect(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Select';
    final options =
        (field['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = (_values[key] as num?)?.toInt() ?? 0;
    final layout = field['layout'] as String? ?? 'row'; // 'row' or 'wrap'

    Widget buildOption(Map<String, dynamic> opt) {
      final label = opt['label'] as String;
      final value = (opt['value'] as num).toInt();
      final colorName = opt['color'] as String? ?? 'grey';
      final color = _resolveColor(colorName);
      final emoji = opt['emoji'] as String?;
      final iconName = opt['icon'] as String?;
      final isSelected = selected == value;

      return OutlinedButton(
        onPressed: () => setState(
            () => _values[key] = (selected == value ? 0 : value).toDouble()),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : color,
          backgroundColor: isSelected ? color : Colors.white,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 22)),
            if (emoji != null) const SizedBox(height: 4),
            if (iconName != null && emoji == null)
              Icon(_resolveIcon(iconName), size: 20),
            if (iconName != null && emoji == null) const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final optWidgets = options.map(buildOption).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index. $question',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.green[900],
          ),
        ),
        const SizedBox(height: 14),
        layout == 'wrap'
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: optWidgets,
              )
            : Row(
                children: optWidgets
                    .map((w) => Expanded(
                          child:
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: w),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  // ── Multi-select chip group (toggle chips) ────────────────────────────

  // ── Multi-select chip group (supports emoji/icon, exclusive) ────────

  Widget _buildMultiSelect(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Select all that apply';
    final options =
        (field['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = (_values[key] as List<String>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index. $question',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.green[900],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: options.map((opt) {
            final label = opt['label'] as String;
            final value = opt['value'] as String;
            final colorName = opt['color'] as String? ?? 'grey';
            final color = _resolveColor(colorName);
            final emoji = opt['emoji'] as String?;
            final iconName = opt['icon'] as String?;
            final isExclusive = opt['exclusive'] == true;
            final isSelected = selected.contains(value);

            return OutlinedButton(
              onPressed: () {
                setState(() {
                  if (isExclusive) {
                    _values[key] = isSelected ? <String>[] : [value];
                  } else {
                    final list = List<String>.from(selected);
                    list.removeWhere((v) {
                      final excl = options.firstWhere(
                        (o) => o['value'] == v && o['exclusive'] == true,
                        orElse: () => <String, dynamic>{},
                      );
                      return excl.isNotEmpty;
                    });
                    if (isSelected) {
                      list.remove(value);
                    } else {
                      list.add(value);
                    }
                    _values[key] = list;
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isSelected ? Colors.white : (isExclusive ? color : Colors.grey[800]),
                backgroundColor:
                    isSelected ? (isExclusive ? color : Colors.grey[800]) : Colors.white,
                side: BorderSide(
                    color: isSelected
                        ? (isExclusive ? color : Colors.grey.shade800)
                        : Colors.grey.shade400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (emoji != null) ...[
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                  ],
                  if (iconName != null && emoji == null) ...[
                    Icon(_resolveIcon(iconName), size: 18),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Emoji scale (row of large emoji buttons, numeric value) ─────────

  Widget _buildEmojiScale(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'How do you feel?';
    final options =
        (field['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = (_values[key] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: options.map((opt) {
            final emoji = opt['emoji'] as String? ?? '❓';
            final value = (opt['value'] as num).toInt();
            final label = opt['label'] as String? ?? '';
            final isSelected = selected == value;

            return GestureDetector(
              onTap: () => setState(
                  () => _values[key] = (selected == value ? 0 : value).toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.green.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSelected ? Colors.green : Colors.transparent,
                      width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji,
                        style: TextStyle(
                            fontSize: isSelected ? 36 : 30)),
                    if (label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.green[800]
                                    : Colors.grey[600])),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Emoji single-select (big emoji cards, single choice) ──────────

  Widget _buildEmojiSingleSelect(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Choose one';
    final options =
        (field['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = (_values[key] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final emoji = opt['emoji'] as String? ?? '❓';
            final label = opt['label'] as String? ?? '';
            final value = (opt['value'] as num).toInt();
            final colorName = opt['color'] as String? ?? 'green';
            final color = _resolveColor(colorName);
            final isSelected = selected == value;

            return GestureDetector(
              onTap: () => setState(
                  () => _values[key] = (selected == value ? 0 : value).toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 90,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.12)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? color
                                : Colors.grey[700])),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Emoji multi-select (big emoji cards, multi choice) ────────────

  Widget _buildEmojiMultiSelect(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Select all that apply';
    final options =
        (field['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final selected = (_values[key] as List<String>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final emoji = opt['emoji'] as String? ?? '❓';
            final label = opt['label'] as String? ?? '';
            final value = opt['value'] as String;
            final colorName = opt['color'] as String? ?? 'green';
            final color = _resolveColor(colorName);
            final isSelected = selected.contains(value);

            return GestureDetector(
              onTap: () {
                setState(() {
                  final list = List<String>.from(selected);
                  if (isSelected) {
                    list.remove(value);
                  } else {
                    list.add(value);
                  }
                  _values[key] = list;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 90,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.12)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? color
                                : Colors.grey[700])),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Star rating (1–N stars) ───────────────────────────────────────

  Widget _buildRatingStars(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Rate';
    final maxStars = (field['max'] as num?)?.toInt() ?? 5;
    final selected = (_values[key] as num?)?.toInt() ?? 0;
    final colorName = field['color'] as String? ?? 'amber';
    final color = _resolveColor(colorName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxStars, (i) {
            final starValue = i + 1;
            final filled = starValue <= selected;
            return GestureDetector(
              onTap: () => setState(() =>
                  _values[key] = (selected == starValue ? 0 : starValue).toDouble()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? color : Colors.grey[400],
                  size: 40,
                ),
              ),
            );
          }),
        ),
        if (selected > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text('$selected / $maxStars',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ),
      ],
    );
  }

  // ── Free text input ───────────────────────────────────────────────

  Widget _buildTextInput(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Comments';
    final hint = field['hint'] as String? ?? 'Type here…';
    final maxLength = (field['maxLength'] as num?)?.toInt() ?? 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        TextField(
          maxLength: maxLength,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade700, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
          onChanged: (v) => setState(() => _values[key] = v),
        ),
      ],
    );
  }

  // ── Yes / No binary toggle ────────────────────────────────────────

  Widget _buildYesNo(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final question = field['question'] as String? ??
        field['label'] as String? ??
        'Yes or No?';
    final yesLabel = field['yesLabel'] as String? ?? 'Yes';
    final noLabel = field['noLabel'] as String? ?? 'No';
    final yesEmoji = field['yesEmoji'] as String?;
    final noEmoji = field['noEmoji'] as String?;
    final value = _values[key]; // null | true | false

    Widget toggle(String label, String? emoji, bool boolVal) {
      final isSelected = value == boolVal;
      final color = boolVal ? Colors.green : Colors.red;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            onPressed: () => setState(
                () => _values[key] = (value == boolVal ? null : boolVal)),
            style: OutlinedButton.styleFrom(
              foregroundColor: isSelected ? Colors.white : color,
              backgroundColor: isSelected ? color : Colors.white,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (emoji != null) ...[
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.green[900])),
        const SizedBox(height: 14),
        Row(children: [
          toggle(yesLabel, yesEmoji, true),
          toggle(noLabel, noEmoji, false),
        ]),
      ],
    );
  }

  // ── Legacy slider field ───────────────────────────────────────────────

  Widget _buildSlider(
      Map<String, dynamic> field, BuildContext context, int index) {
    final key = field['key'] as String;
    final label =
        field['question'] as String? ?? field['label'] as String? ?? key;
    final min = (field['min'] as num?)?.toDouble() ?? 1;
    final max = (field['max'] as num?)?.toDouble() ?? 5;
    final value = (_values[key] as num?)?.toDouble() ?? min;
    final labels = field['labels'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$index. $label',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              Text(value.round().toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: (v) => setState(() => _values[key] = v),
          ),
          if (labels != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(labels[min.round().toString()] ?? '',
                    style: Theme.of(context).textTheme.bodySmall),
                if (labels.containsKey(((min + max) / 2).round().toString()))
                  Text(labels[((min + max) / 2).round().toString()] ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                Text(labels[max.round().toString()] ?? '',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Color _resolveColor(String name) {
    const map = <String, Color>{
      'orange': Colors.orange,
      'green': Color(0xFF4CAF50),
      'blue': Color(0xFF2196F3),
      'red': Colors.red,
      'amber': Colors.amber,
      'grey': Colors.grey,
      'black': Colors.black,
      'teal': Color(0xFF009688),
      'purple': Color(0xFF9C27B0),
      'cyan': Color(0xFF00BCD4),
      'pink': Color(0xFFE91E63),
      'indigo': Color(0xFF3F51B5),
      'brown': Color(0xFF795548),
      'lime': Color(0xFFCDDC39),
      'deepOrange': Color(0xFFFF5722),
      'yellow': Color(0xFFFFEB3B),
    };
    return map[name] ?? Colors.grey;
  }

  IconData _resolveIcon(String name) {
    const map = <String, IconData>{
      'thermostat': Icons.thermostat,
      'wb_sunny': Icons.wb_sunny,
      'ac_unit': Icons.ac_unit,
      'air': Icons.air,
      'water_drop': Icons.water_drop,
      'volume_up': Icons.volume_up,
      'volume_off': Icons.volume_off,
      'lightbulb': Icons.lightbulb,
      'light_mode': Icons.light_mode,
      'dark_mode': Icons.dark_mode,
      'chair': Icons.chair,
      'desk': Icons.desk,
      'meeting_room': Icons.meeting_room,
      'groups': Icons.groups,
      'person': Icons.person,
      'check_circle': Icons.check_circle,
      'cancel': Icons.cancel,
      'thumb_up': Icons.thumb_up,
      'thumb_down': Icons.thumb_down,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'eco': Icons.eco,
      'bolt': Icons.bolt,
      'wifi': Icons.wifi,
      'coffee': Icons.coffee,
      'restaurant': Icons.restaurant,
      'fitness_center': Icons.fitness_center,
      'spa': Icons.spa,
      'warning': Icons.warning,
      'info': Icons.info,
    };
    return map[name] ?? Icons.help_outline;
  }

  void _submit() {
    final payload = <String, dynamic>{};
    for (final entry in _values.entries) {
      final val = entry.value;
      if (val is List) {
        payload[entry.key] = val;
      } else if (val is String) {
        payload[entry.key] = val;
      } else if (val is bool) {
        payload[entry.key] = val;
      } else if (val is num) {
        payload[entry.key] = val.round();
      } else {
        payload[entry.key] = val;
      }
    }
    widget.onSubmit(payload);
  }
}

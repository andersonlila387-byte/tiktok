import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dialog with one numeric field per entry. Returns the edited values, or null
/// if cancelled. Keys are shown as field labels, in insertion order.
Future<Map<String, double>?> showValuesEditor(
  BuildContext context, {
  required String title,
  required Map<String, num> initial,
  String? suffix,
  bool integer = true,
  String? helper,
  double? maxTotal,
}) {
  return showDialog<Map<String, double>>(
    context: context,
    builder: (_) => _ValuesEditor(
      title: title,
      initial: initial,
      suffix: suffix,
      integer: integer,
      helper: helper,
      maxTotal: maxTotal,
    ),
  );
}

class _ValuesEditor extends StatefulWidget {
  const _ValuesEditor({
    required this.title,
    required this.initial,
    required this.integer,
    this.suffix,
    this.helper,
    this.maxTotal,
  });

  final String title;
  final Map<String, num> initial;
  final String? suffix;
  final bool integer;
  final String? helper;
  final double? maxTotal;

  @override
  State<_ValuesEditor> createState() => _ValuesEditorState();
}

class _ValuesEditorState extends State<_ValuesEditor> {
  late final Map<String, TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final e in widget.initial.entries)
        e.key: TextEditingController(
          text: widget.integer
              ? e.value.round().toString()
              : e.value.toStringAsFixed(1),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final out = <String, double>{};
    for (final e in _controllers.entries) {
      final v = double.tryParse(e.value.text.trim());
      if (v == null || v < 0) {
        setState(() => _error = 'Enter a valid number for "${e.key}".');
        return;
      }
      out[e.key] = widget.integer ? v.roundToDouble() : v;
    }
    final max = widget.maxTotal;
    if (max != null && out.values.fold<double>(0, (a, b) => a + b) > max) {
      setState(() => _error = 'Values can add up to at most ${max.round()}.');
      return;
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final multi = _controllers.length > 1;
    return AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.title, style: t(15, weight: FontWeight.w600)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.helper != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.helper!,
                    style: t(12, color: AppColors.muted),
                  ),
                ),
              for (final e in _controllers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: e.value,
                    autofocus: !multi,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !widget.integer,
                    ),
                    decoration: InputDecoration(
                      labelText: e.key,
                      suffixText: widget.suffix,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: multi ? null : (_) => _save(),
                  ),
                ),
              if (_error != null)
                Text(_error!, style: t(12, color: AppColors.down)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/value_editor.dart';

/// Asks for the admin PIN, checks it with the server, then opens the admin
/// screen.
Future<void> openAdmin(BuildContext context) async {
  final p = context.read<AnalyticsProvider>();
  final controller = TextEditingController();
  String? error;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> submit() async {
          if (busy) return;
          setState(() {
            busy = true;
            error = null;
          });
          try {
            if (await p.login(controller.text)) {
              if (ctx.mounted) Navigator.pop(ctx, true);
              return;
            }
            error = 'Incorrect PIN';
          } on StorageException catch (e) {
            error = e.message;
          }
          if (ctx.mounted) setState(() => busy = false);
        }

        return AlertDialog(
          title: const Text('Admin access'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: const Text('Enter'),
            ),
          ],
        );
      },
    ),
  );
  // Not disposed: the dialog is still animating closed and reads it.
  if (ok == true && context.mounted) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AdminScreen()));
  }
}

/// Edits one series' per-day values through a dialog; returns them in window
/// order, or null if cancelled.
Future<List<int>?> _editPoints(
  BuildContext context, {
  required String title,
  required List<DateTime> dates,
  required List<int> values,
  bool money = false,
}) async {
  final result = await showValuesEditor(
    context,
    title: title,
    helper: 'Edit the value for each day.',
    integer: !money,
    initial: {
      for (var i = 0; i < dates.length; i++)
        shortDate(dates[i]): money ? values[i] / 100 : values[i],
    },
  );
  return result?.values
      .map((v) => money ? (v * 100).round() : v.round())
      .toList();
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final d = p.data;
    final dates = p.windowDates;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (p.syncError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.syncError!, style: t(13, color: AppColors.down)),
            ),
          _Group(
            title: 'Date range',
            note: 'Totals and daily values below apply to this range.',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in AnalyticsProvider.ranges)
                      ButtonSegment(value: r, label: Text('${r}d')),
                  ],
                  selected: {p.rangeDays},
                  onSelectionChanged: (s) => p.setRange(s.first),
                ),
              ),
            ],
          ),
          _Group(
            title: 'Metrics',
            note: 'Totals rescale the daily values to match.',
            children: [
              for (final k in d.metrics.keys)
                _MetricRow(metricKey: k, p: p, dates: dates),
            ],
          ),
          _Group(
            title: 'Followers',
            children: [
              _Row(
                title: 'Total followers',
                value: grouped(p.totalFollowers),
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Total followers',
                    helper: 'The whole trend line shifts to match.',
                    initial: {'Total': p.totalFollowers},
                  );
                  if (r != null) p.setTotalFollowers(r['Total']!.round());
                },
              ),
              _Row(
                title: 'Net followers (${p.rangeDays} days)',
                value: grouped(p.netFollowers),
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Net followers (${p.rangeDays} days)',
                    helper: 'Earlier days are adjusted to match.',
                    initial: {'Net': p.netFollowers},
                  );
                  if (r != null) p.setNetFollowers(r['Net']!.round());
                },
              ),
              _Row(
                title: 'Daily follower counts',
                value: '${p.rangeDays} days',
                onTap: () async {
                  final r = await _editPoints(
                    context,
                    title: 'Total followers by day',
                    dates: dates,
                    values: p.followerWindow,
                  );
                  if (r != null) p.setFollowerWindow(r);
                },
              ),
              _Row(
                title: 'Gender',
                value: '${d.male.round()}% / ${d.female.round()}%',
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Gender',
                    integer: false,
                    suffix: '%',
                    maxTotal: 100,
                    helper: 'Other is whatever remains of 100%.',
                    initial: {'Male': d.male, 'Female': d.female},
                  );
                  if (r != null) p.setGender(r['Male']!, r['Female']!);
                },
              ),
              _Row(
                title: 'Age groups',
                value: '${d.ages.length} groups',
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Age groups',
                    integer: false,
                    suffix: '%',
                    maxTotal: 100,
                    initial: d.ages,
                  );
                  if (r != null) p.setAges(r);
                },
              ),
              _Row(
                title: 'Locations',
                value: '${d.locations.length} countries',
                onTap: () async {
                  final text = await _editLines(
                    context,
                    title: 'Locations',
                    helper: 'One per line: name, percent',
                    initial: [
                      for (final l in d.locations) '${l.name}, ${l.percent}',
                    ],
                  );
                  if (text == null) return;
                  final list = <LocationShare>[];
                  for (final line in text) {
                    final i = line.lastIndexOf(',');
                    if (i < 1) continue;
                    final pct = double.tryParse(line.substring(i + 1).trim());
                    if (pct == null) continue;
                    list.add(LocationShare(line.substring(0, i).trim(), pct));
                  }
                  p.setLocations(list);
                },
              ),
              _Row(
                title: 'Active followers by hour',
                value: '24 values',
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Active followers by hour',
                    initial: {
                      for (var h = 0; h < 24; h++) hourLabel(h): d.hourly[h],
                    },
                  );
                  if (r != null) {
                    p.setHourly(r.values.map((v) => v.round()).toList());
                  }
                },
              ),
              _Row(
                title: 'Active followers by day',
                value: '7 values',
                onTap: () async {
                  final r = await showValuesEditor(
                    context,
                    title: 'Active followers by day',
                    initial: {
                      for (var i = 0; i < 7; i++) weekdayNames[i]: d.weekday[i],
                    },
                  );
                  if (r != null) {
                    p.setWeekday(r.values.map((v) => v.round()).toList());
                  }
                },
              ),
            ],
          ),
          _Group(
            title: 'Comments',
            children: [
              _Row(
                title: 'Top words',
                value: '${d.topWords.length} words',
                onTap: () async {
                  final text = await _editLines(
                    context,
                    title: 'Top words in comments',
                    helper: 'One per line: word, count',
                    initial: [
                      for (final w in d.topWords) '${w.word}, ${w.count}',
                    ],
                  );
                  if (text == null) return;
                  final list = <WordCount>[];
                  for (final line in text) {
                    final i = line.lastIndexOf(',');
                    if (i < 1) continue;
                    final n = int.tryParse(line.substring(i + 1).trim());
                    if (n == null || n < 0) continue;
                    list.add(WordCount(line.substring(0, i).trim(), n));
                  }
                  p.setTopWords(list);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset all figures?'),
                  content: const Text('Everything returns to the sample data.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                await p.resetToSample();
              } on StorageException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            icon: const Icon(LucideIcons.rotateCcw, size: 16),
            label: const Text('Reset to sample data'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Multi-line text dialog; returns the non-empty lines or null if cancelled.
Future<List<String>?> _editLines(
  BuildContext context, {
  required String title,
  required String helper,
  required List<String> initial,
}) {
  final controller = TextEditingController(text: initial.join('\n'));
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: t(15, weight: FontWeight.w600)),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: controller,
          maxLines: 10,
          minLines: 6,
          decoration: InputDecoration(
            helperText: helper,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            controller.text
                .split('\n')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList(),
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.note});

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(note!, style: t(12, color: AppColors.muted)),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppColors.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title, style: t(14)),
      subtitle: Text(value, style: t(12, color: AppColors.muted)),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: AppColors.muted,
      ),
      onTap: onTap,
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metricKey,
    required this.p,
    required this.dates,
  });

  final String metricKey;
  final AnalyticsProvider p;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final isMoney = metricKey == 'Est. rewards';
    final total = p.metricTotal(metricKey);
    return ListTile(
      dense: true,
      title: Text(metricKey, style: t(14)),
      subtitle: Text(
        '${formatMetric(metricKey, total)} · ${p.rangeDays} days',
        style: t(12, color: AppColors.muted),
      ),
      trailing: TextButton(
        onPressed: () async {
          final r = await _editPoints(
            context,
            title: '$metricKey by day',
            dates: dates,
            values: p.metricWindow(metricKey),
            money: isMoney,
          );
          if (r != null) p.setMetricWindow(metricKey, r);
        },
        child: const Text('Daily'),
      ),
      onTap: () async {
        final r = await showValuesEditor(
          context,
          title: '$metricKey (${p.rangeDays} days)',
          helper: 'Daily values are rescaled to match the total.',
          integer: !isMoney,
          suffix: isMoney ? 'USD' : null,
          initial: {'Total': isMoney ? total / 100 : total},
        );
        if (r == null) return;
        p.setMetricTotal(
          metricKey,
          isMoney ? (r['Total']! * 100).round() : r['Total']!.round(),
        );
      },
    );
  }
}

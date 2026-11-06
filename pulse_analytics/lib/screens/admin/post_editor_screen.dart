import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/picture_field.dart';

/// One numeric box of the form and how it reads from / writes to a [Post].
class _Num {
  const _Num(
    this.label,
    this.get,
    this.set, {
    this.help,
    this.decimal = false,
    this.signed = false,
  });

  final String label;
  final String? help;
  final num Function(Post) get;
  final void Function(Post, double) set;
  final bool decimal;
  final bool signed;
}

class _Section {
  const _Section(this.title, this.fields, {this.note});
  final String title;
  final String? note;
  final List<_Num> fields;
}

final _sections = <_Section>[
  _Section('Video', [
    _Num(
      'Video length (seconds)',
      (p) => p.durationSec,
      (p, v) => p.durationSec = v,
      decimal: true,
    ),
  ]),
  _Section('Counts under the cover', [
    _Num('Views', (p) => p.views, (p, v) => p.views = v.round()),
    _Num('Likes', (p) => p.likes, (p, v) => p.likes = v.round()),
    _Num('Comments', (p) => p.comments, (p, v) => p.comments = v.round()),
    _Num('Shares', (p) => p.shares, (p, v) => p.shares = v.round()),
    _Num('Saves', (p) => p.saves, (p, v) => p.saves = v.round()),
  ]),
  _Section('Overview', [
    _Num(
      'Total play time (seconds)',
      (p) => p.playTimeSec,
      (p, v) => p.playTimeSec = v.round(),
      help: '383 shows as 0h:06m:23s',
    ),
    _Num(
      'Average watch time (seconds)',
      (p) => p.avgWatchSec,
      (p, v) => p.avgWatchSec = v,
      decimal: true,
    ),
    _Num(
      'Watched full video (%)',
      (p) => p.fullWatchPct,
      (p, v) => p.fullWatchPct = v,
      decimal: true,
    ),
    _Num(
      'New followers',
      (p) => p.newFollowers,
      (p, v) => p.newFollowers = v.round(),
    ),
    _Num(
      'Average share of video watched (%)',
      (p) => p.avgWatchedPct,
      (p, v) => p.avgWatchedPct = v,
      decimal: true,
      help: 'Shapes the retention chart. Leave 0 to hide it.',
    ),
    _Num(
      'Most viewers stopped at (seconds)',
      (p) => p.stopSec,
      (p, v) => p.stopSec = v,
      decimal: true,
    ),
  ]),
  _Section('Viewers', [
    _Num(
      'Total viewers',
      (p) => p.totalViewers,
      (p, v) => p.totalViewers = v.round(),
    ),
    _Num(
      'Change vs 1 day ago',
      (p) => p.viewersChange,
      (p, v) => p.viewersChange = v.round(),
      signed: true,
    ),
    _Num(
      'New viewers',
      (p) => p.newViewers,
      (p, v) => p.newViewers = v.round(),
      help: 'The rest of the total are returning viewers.',
    ),
    _Num(
      'Viewers who follow you',
      (p) => p.followerViewers,
      (p, v) => p.followerViewers = v.round(),
      help: 'The rest of the total are non-followers.',
    ),
  ]),
  _Section(
    'Gender',
    note:
        'Enter how many viewers of each kind, for example 5 female and 2 '
        'other. Percentages are worked out for you.',
    [
      _Num('Female', (p) => p.female, (p, v) => p.female = v.round()),
      _Num('Male', (p) => p.male, (p, v) => p.male = v.round()),
      _Num('Other', (p) => p.other, (p, v) => p.other = v.round()),
    ],
  ),
  _Section('Age', note: 'Number of viewers in each age group.', [
    for (var i = 0; i < kAgeGroups.length; i++)
      _Num(kAgeGroups[i], (p) => p.ages[i], (p, v) => p.ages[i] = v.round()),
  ]),
  _Section('Engagement', [
    _Num(
      'Most viewers liked at (seconds)',
      (p) => p.likePeakSec,
      (p, v) => p.likePeakSec = v,
      decimal: true,
    ),
  ]),
];

class _Lines {
  const _Lines(this.label, this.help, this.get, this.set);

  final String label;
  final String help;
  final List<Tally> Function(Post) get;
  final void Function(Post, List<Tally>) set;
}

final _lineFields = <_Lines>[
  _Lines(
    'Locations',
    'One per line: country, number of viewers',
    (p) => p.locations,
    (p, v) => p.locations = v,
  ),
  _Lines(
    'Traffic sources',
    'One per line: source, number of views',
    (p) => p.traffic,
    (p, v) => p.traffic = v,
  ),
  _Lines(
    'Search queries',
    'One per line: search words, number of views',
    (p) => p.queries,
    (p, v) => p.queries = v,
  ),
  _Lines(
    'Top words in comments',
    'One per line: word, times used',
    (p) => p.topWords,
    (p, v) => p.topWords = v,
  ),
];

String _numText(num v) => v == 0 ? '' : plain(v);

/// Adds a post or edits one. Nothing is saved until "Save" is pressed.
class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({super.key, this.post});

  /// The post to edit; null starts a new one.
  final Post? post;

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  late final Post _draft = widget.post == null
      ? Post.blank()
      : Post.fromJson(widget.post!.toJson());
  late final _caption = TextEditingController(text: _draft.caption);
  late String _thumb = _draft.thumbnailUrl;
  late final Map<_Num, TextEditingController> _nums = {
    for (final s in _sections)
      for (final f in s.fields)
        f: TextEditingController(text: _numText(f.get(_draft))),
  };
  late final Map<_Lines, TextEditingController> _lines = {
    for (final f in _lineFields)
      f: TextEditingController(
        text: [for (final t in f.get(_draft)) '${t.name}, ${t.count}']
            .join('\n'),
      ),
  };
  late DateTime _postedAt = _draft.postedAt;
  String? _error;

  bool get _isNew => widget.post == null;

  @override
  void dispose() {
    _caption.dispose();
    for (final c in [..._nums.values, ..._lines.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _postedAt,
      firstDate: DateTime(2016),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_postedAt),
    );
    if (time == null) return;
    setState(() {
      _postedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  List<Tally>? _parseLines(String text, String label) {
    final out = <Tally>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final i = line.lastIndexOf(',');
      final n = i < 1 ? null : int.tryParse(line.substring(i + 1).trim());
      if (n == null || n < 0) {
        setState(() => _error = '$label: "$line" should look like "name, 12".');
        return null;
      }
      out.add(Tally(line.substring(0, i).trim(), n));
    }
    return out;
  }

  void _save() {
    for (final e in _nums.entries) {
      final text = e.value.text.trim();
      final v = text.isEmpty ? 0.0 : double.tryParse(text);
      if (v == null || (v < 0 && !e.key.signed)) {
        setState(() => _error = 'Enter a valid number for "${e.key.label}".');
        return;
      }
      e.key.set(_draft, v);
    }
    for (final e in _lines.entries) {
      final list = _parseLines(e.value.text, e.key.label);
      if (list == null) return;
      e.key.set(_draft, list);
    }
    _draft
      ..caption = _caption.text.trim()
      ..thumbnailUrl = _thumb
      ..postedAt = _postedAt;
    final p = context.read<AnalyticsProvider>();
    if (_isNew) {
      p.addPost(_draft);
    } else {
      p.updatePost(_draft);
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('Its figures are removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AnalyticsProvider>().deletePost(_draft.id);
    Navigator.of(context).pop();
  }

  Widget _heading(String title, {String? note}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t(15, weight: FontWeight.w700)),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note, style: t(12, color: AppColors.muted)),
          ),
      ],
    ),
  );

  Widget _numField(_Num f) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _nums[f],
      keyboardType: TextInputType.numberWithOptions(
        decimal: f.decimal,
        signed: f.signed,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(f.decimal ? r'[-0-9.]' : r'[-0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: f.label,
        helperText: f.help,
        hintText: '0',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isNew ? 'New post' : 'Edit post',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete post',
              icon: const Icon(LucideIcons.trash, size: 20),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          _heading('Post'),
          TextField(
            controller: _caption,
            decoration: const InputDecoration(
              labelText: 'Caption',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          PictureField(
            label: 'Cover picture',
            value: _thumb,
            width: 72,
            height: 96,
            onChanged: (v) => setState(() => _thumb = v),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(LucideIcons.calendar, size: 18),
            label: Text('Posted on ${postedOn(_postedAt)}'),
          ),
          for (final s in _sections) ...[
            _heading(s.title, note: s.note),
            for (final f in s.fields) _numField(f),
          ],
          _heading(
            'Lists',
            note: 'Leave a list empty to show "Data will be shown…".',
          ),
          for (final f in _lineFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _lines[f],
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: f.label,
                  helperText: f.help,
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!, style: t(13, color: AppColors.down)),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save post')),
        ],
      ),
    );
  }
}

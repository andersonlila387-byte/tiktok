import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picture_field.dart';

/// Edits one "Creation Inspiration" list: add, remove and change posts, each
/// with its own cover picture and author picture. Saved with "Save".
class InspirationEditorScreen extends StatefulWidget {
  const InspirationEditorScreen({
    super.key,
    required this.listKey,
    required this.title,
  });

  final String listKey;
  final String title;

  @override
  State<InspirationEditorScreen> createState() =>
      _InspirationEditorScreenState();
}

class _InspirationEditorScreenState extends State<InspirationEditorScreen> {
  late final List<InspirationPost> _items = [
    for (final e
        in context.read<AnalyticsProvider>().data.inspiration[widget.listKey] ??
            <InspirationPost>[])
      InspirationPost(
        e.caption,
        e.likes,
        e.author,
        image: e.image,
        avatar: e.avatar,
      ),
  ];

  void _save() {
    context.read<AnalyticsProvider>().setInspiration(widget.listKey, [
      for (final e in _items)
        if (e.caption.trim().isNotEmpty || e.image.isNotEmpty) e,
    ]);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          for (var i = 0; i < _items.length; i++)
            _ItemCard(
              key: ObjectKey(_items[i]),
              number: i + 1,
              item: _items[i],
              onDelete: () => setState(() => _items.removeAt(i)),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _items.add(InspirationPost('', '', '')),
            ),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add a post'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save list')),
        ],
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.number,
    required this.item,
    required this.onDelete,
  });

  final int number;
  final InspirationPost item;
  final VoidCallback onDelete;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${widget.number}', style: t(14, weight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove this post',
                  icon: const Icon(LucideIcons.trash, size: 18),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            PictureField(
              label: 'Cover picture',
              value: item.image,
              onChanged: (v) => setState(() => item.image = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: item.caption,
              minLines: 1,
              maxLines: 3,
              decoration: _deco('Caption'),
              onChanged: (v) => item.caption = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item.likes,
              decoration: _deco('Likes (for example 6M or 566.7K)'),
              onChanged: (v) => item.likes = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item.author,
              decoration: _deco('Author name'),
              onChanged: (v) => item.author = v,
            ),
            const SizedBox(height: 12),
            PictureField(
              label: 'Author picture',
              value: item.avatar,
              width: 40,
              height: 40,
              maxWidth: 160,
              round: true,
              onChanged: (v) => setState(() => item.avatar = v),
            ),
          ],
        ),
      ),
    );
  }
}

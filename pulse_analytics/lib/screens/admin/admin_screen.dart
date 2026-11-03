import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/analytics_data.dart';
import '../../providers/analytics_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/ui.dart';
import 'inspiration_editor_screen.dart';
import 'post_editor_screen.dart';

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
            error = 'Incorrect password';
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
            decoration: InputDecoration(
              labelText: 'Password',
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminScreen()));
  }
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _edit(BuildContext context, Post? post) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PostEditorScreen(post: post)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final d = p.data;

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
          FilledButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add a post'),
          ),
          const SizedBox(height: 8),
          _Group(
            title: 'Posts',
            note:
                'Visitors see the first post. To show another one, add '
                '?v=<post id> to the address; Copy link does that for you.',
            children: [
              if (d.posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No posts yet. Tap "Add a post".'),
                ),
              for (final post in d.posts)
                ListTile(
                  leading: VideoCover(
                    url: post.thumbnailUrl,
                    width: 36,
                    height: 48,
                    radius: 4,
                  ),
                  title: Text(
                    post.caption.isEmpty ? '(no caption)' : post.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(14),
                  ),
                  subtitle: Text(
                    '${grouped(post.views)} views · ${postedOn(post.postedAt)}',
                    style: t(12, color: AppColors.muted),
                  ),
                  trailing: IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(LucideIcons.link, size: 18),
                    onPressed: () async {
                      final link = Uri.base
                          .replace(
                            queryParameters: {'v': post.id},
                            fragment: '',
                          )
                          .toString();
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                  ),
                  onTap: () => _edit(context, post),
                ),
            ],
          ),
          _Group(
            title: 'Creation Inspiration',
            note:
                'Add, remove and change the posts in each list, with their '
                'own pictures.',
            children: [
              for (final (key, title) in const [
                ('trending', 'Trending posts'),
                ('similar', 'Similar posts'),
                ('followers', 'Followers viewed'),
              ])
                _Row(
                  title: title,
                  value: '${d.inspiration[key]?.length ?? 0} posts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InspirationEditorScreen(
                        listKey: key,
                        title: title,
                      ),
                    ),
                  ),
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
                  content: const Text(
                    'Every post is removed and the sample data returns.',
                  ),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
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

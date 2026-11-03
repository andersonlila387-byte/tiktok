import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/image_upload.dart';
import 'ui.dart';

/// Admin control for one picture: shows it, and lets the admin upload a new
/// one from their device, paste a web address, or remove it (back to the
/// placeholder).
class PictureField extends StatelessWidget {
  const PictureField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 54,
    this.height = 72,
    this.maxWidth = 480,
    this.round = false,
  });

  final String label;

  /// Current picture (a `data:` link or web address); empty for none.
  final String value;
  final ValueChanged<String> onChanged;
  final double width;
  final double height;

  /// Uploads are shrunk to this width before they are saved.
  final double maxWidth;
  final bool round;

  Future<void> _upload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickPicture(maxWidth: maxWidth);
      if (picked != null) onChanged(picked);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _link(BuildContext context) async {
    final controller = TextEditingController(
      text: value.startsWith('data:') ? '' : value,
    );
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: t(15, weight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Picture link',
            hintText: 'https://…/picture.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Use link'),
          ),
        ],
      ),
    );
    if (text != null) onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        VideoCover(
          url: value,
          width: width,
          height: height,
          radius: round ? width / 2 : 6,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t(13, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _upload(context),
                    icon: const Icon(LucideIcons.upload, size: 15),
                    label: Text(value.isEmpty ? 'Upload' : 'Replace'),
                  ),
                  TextButton(
                    onPressed: () => _link(context),
                    child: const Text('Use link'),
                  ),
                  if (value.isNotEmpty)
                    TextButton(
                      onPressed: () => onChanged(''),
                      child: Text(
                        'Remove',
                        style: t(14, color: AppColors.down),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

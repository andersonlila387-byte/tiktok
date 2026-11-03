import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/image_upload.dart';

/// White rounded panel used for every section.
class TkCard extends StatelessWidget {
  const TkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(3),
      ),
      child: child,
    );
  }
}

/// Bold section heading, optionally followed by the round "i" icon.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.info = true});

  final String text;
  final bool info;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(text, style: t(17, weight: FontWeight.w700, height: 1.2)),
        ),
        if (info) ...[
          const SizedBox(width: 6),
          const Icon(LucideIcons.info, size: 15, color: Color(0xFF6C6D72)),
        ],
      ],
    );
  }
}

/// Small grey explanatory paragraph.
class BodyText extends StatelessWidget {
  const BodyText(this.text, {super.key, this.align, this.color});

  final String text;
  final TextAlign? align;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: t(14, color: color ?? AppColors.muted, height: 1.3),
    );
  }
}

/// Fully rounded pill; black when selected.
class PillChip extends StatelessWidget {
  const PillChip(
    this.label,
    this.selected,
    this.onTap, {
    super.key,
    this.horizontal = 16,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFEBEBEB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: t(
            14,
            weight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.chipText,
          ),
        ),
      ),
    );
  }
}

/// Cover image of a video: the picture when there is one, otherwise a dark
/// placeholder. [child] is drawn over it (duration, play button).
class VideoCover extends StatelessWidget {
  const VideoCover({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 6,
    this.child,
  });

  final String url;
  final double width;
  final double height;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A5C66), Color(0xFF22232A)],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.video,
          size: width * 0.28,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.trim().isEmpty
                ? placeholder
                : Image(
                    image: pictureProvider(url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Grey placeholder shown until a video has enough views for a section.
const kNeedViewsNotice = 'Data will be shown when this video reaches 100 views.';

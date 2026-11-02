import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';

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
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
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
          child: Text(text, style: t(20, weight: FontWeight.w700, height: 1.2)),
        ),
        if (info) ...[
          const SizedBox(width: 6),
          const Icon(LucideIcons.info, size: 17, color: Color(0xFF6C6D72)),
        ],
      ],
    );
  }
}

/// Small grey explanatory paragraph.
class BodyText extends StatelessWidget {
  const BodyText(this.text, {super.key, this.align});

  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: t(15, color: AppColors.muted, height: 1.3),
    );
  }
}

/// Rounded-rectangle filter chip (Gender / Age / Locations, Hours / Days...).
class SquareChip extends StatelessWidget {
  const SquareChip(this.label, this.selected, this.onTap, {super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTint : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: t(
            15,
            weight: FontWeight.w500,
            color: selected ? const Color(0xFF1274D2) : AppColors.muted,
          ),
        ),
      ),
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
    this.horizontal = 13,
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
            15,
            weight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.chipText,
          ),
        ),
      ),
    );
  }
}

/// Dismissable notice card ("Update to ...").
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t(18, weight: FontWeight.w600, height: 1.2)),
                const SizedBox(height: 6),
                BodyText(body),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.only(left: 12, top: 2),
              child: Icon(LucideIcons.x, size: 22, color: Color(0xFF55565B)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "7 days / 28 days / 60 days / 365 days / Custom" selector under the tabs.
class RangeChips extends StatelessWidget {
  const RangeChips({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        children: [
          for (final d in AnalyticsProvider.ranges) ...[
            PillChip(
              '$d days',
              !p.customRange && p.rangeDays == d,
              () => p.setRange(d),
            ),
            const SizedBox(width: 8),
          ],
          PillChip('Custom', p.customRange, () => _pickCustom(context, p)),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context, AnalyticsProvider p) async {
    final dates = p.windowDates;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: p.earliestDate,
      lastDate: p.lastDataDate,
      initialDateRange: DateTimeRange(start: dates.first, end: dates.last),
    );
    if (picked != null) p.setCustomRange(picked.start, picked.end);
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'trend_chart.dart';
import 'ui.dart';

class MetricTileData {
  const MetricTileData({
    required this.title,
    required this.value,
    required this.delta,
    required this.series,
    this.up,
    this.faintDelta = false,
  });

  final String title;
  final String value;
  final String delta;

  /// Direction of the change; null shows no arrow.
  final bool? up;

  /// Lighter delta text, for captions such as "All time".
  final bool faintDelta;
  final List<int> series;
}

/// "Key metrics" card: a grid of figures and the trend of the selected one.
class KeyMetricsCard extends StatefulWidget {
  const KeyMetricsCard({super.key, required this.tiles, required this.dates});

  final List<MetricTileData> tiles;
  final List<DateTime> dates;

  @override
  State<KeyMetricsCard> createState() => _KeyMetricsCardState();
}

class _KeyMetricsCardState extends State<KeyMetricsCard> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final i = _selected.clamp(0, widget.tiles.length - 1);
    final tile = widget.tiles[i];
    final range =
        '${shortDate(widget.dates.first)} - ${shortDate(widget.dates.last)}';

    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Key metrics'),
          const SizedBox(height: 4),
          Text(range, style: t(15, color: AppColors.muted)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var k = 0; k < widget.tiles.length; k++)
                    SizedBox(
                      width: w,
                      child: _Tile(
                        data: widget.tiles[k],
                        selected: k == i,
                        onTap: () => setState(() => _selected = k),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TrendChart(
              key: ValueKey('${tile.title}-${widget.dates.length}'),
              values: tile.series,
              dates: widget.dates,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final MetricTileData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = data.up;
    final color = data.faintDelta
        ? AppColors.faint
        : up == true
        ? AppColors.up
        : AppColors.neutralDelta;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedTile : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF4C98E0) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t(15.5, weight: FontWeight.w500),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                style: t(29, weight: FontWeight.w700, height: 1.2),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (up != null) ...[
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      up ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    data.delta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(14.5, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

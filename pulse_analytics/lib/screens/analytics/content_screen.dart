import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analytics_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  static const _sorts = [
    'Most views',
    'Most new viewers',
    'Most likes',
    'Most comments',
    'Most shares',
  ];
  int _sort = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (!p.contentNoteDismissed)
                NoteCard(
                  title: 'Update to “Posts”',
                  body:
                      'As part of our recent updates to improve the user '
                      'experience, this section has been removed. You can view '
                      'and manage your posts on the “Profile” page.',
                  onClose: p.dismissContentNote,
                ),
            ]),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TkCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardTitle('Your top posts'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sorts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => SquareChip(
                        _sorts[i],
                        i == _sort,
                        () => setState(() => _sort = i),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No top posts',
                            style: t(20, weight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: BodyText(
                              'Your posts haven’t received an increase in '
                              'views during the selected period.',
                              align: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

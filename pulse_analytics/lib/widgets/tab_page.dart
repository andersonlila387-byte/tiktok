import 'package:flutter/material.dart';

/// Scrolling body of one tab. It leaves room for the pinned tab bar and keeps
/// its own scroll position when the visitor switches tabs.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 24),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

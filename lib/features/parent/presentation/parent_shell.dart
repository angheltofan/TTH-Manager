import 'package:flutter/material.dart';

import 'widgets/parent_responsive_scaffold.dart';

/// Mounted **once** by the `ShellRoute` in `router.dart` for every
/// `/parent/*` page. Delegates to [ParentResponsiveScaffold] which owns
/// the persistent sidebar, top bar, bottom nav and realtime channel.
/// Individual pages render only their body content in [child].
class ParentShell extends StatelessWidget {
  const ParentShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ParentResponsiveScaffold(child: child);
  }
}

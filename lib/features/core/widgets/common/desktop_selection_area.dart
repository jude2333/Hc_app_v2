import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a [SelectionArea] on web/desktop platforms,
/// enabling drag-to-select and Ctrl+C across multiple Text widgets.
/// On mobile, returns [child] unchanged to avoid touch selection conflicts.
class DesktopSelectionArea extends StatelessWidget {
  final Widget child;

  const DesktopSelectionArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return SelectionArea(child: child);
  }
}

import 'package:flutter/widgets.dart';

import 'river_destination.dart';

/// How the shell currently presents navigation.
enum RiverNavigationForm {
  /// Destinations in a bar along the bottom edge.
  bottomBar,

  /// Icons with short labels in a narrow column on the start edge.
  rail,

  /// Full labels in a wide column on the start edge.
  sidebar,
}

/// Shell state that pages inside the shell read.
class RiverShellScope extends InheritedWidget {
  const RiverShellScope({
    super.key,
    required this.form,
    required this.primaryAction,
    required this.navigationCount,
    required super.child,
  });

  final RiverNavigationForm form;
  final RiverShellAction? primaryAction;

  /// Increments each time the selected destination changes. Page headers use
  /// it to move focus to the new page's title.
  final int navigationCount;

  static RiverShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RiverShellScope>();

  @override
  bool updateShouldNotify(RiverShellScope oldWidget) =>
      form != oldWidget.form ||
      primaryAction != oldWidget.primaryAction ||
      navigationCount != oldWidget.navigationCount;
}

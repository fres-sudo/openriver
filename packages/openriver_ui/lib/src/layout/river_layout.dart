import 'package:flutter/widgets.dart';

import 'window_class.dart';

/// Parts of [RiverLayoutData] that a widget can depend on separately.
enum RiverLayoutAspect { window, navigation, content }

/// Responsive classes for one place in the widget tree.
@immutable
final class RiverLayoutData {
  const RiverLayoutData({
    required this.window,
    required this.navigation,
    required this.content,
  });

  /// Derives classes from the nearest [MediaQuery]. Content matches the window.
  factory RiverLayoutData.fromMediaQuery(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final window = RiverWindowClass.fromWidth(width);
    return RiverLayoutData(
      window: window,
      navigation: RiverWindowClass.forNavigation(
        width,
        MediaQuery.textScalerOf(context),
      ),
      content: window,
    );
  }

  /// Width class of the whole window.
  final RiverWindowClass window;

  /// Window class adjusted for text scale, used to choose navigation.
  final RiverWindowClass navigation;

  /// Width class of the region the current widget is laid out in.
  final RiverWindowClass content;

  RiverLayoutData copyWith({
    RiverWindowClass? window,
    RiverWindowClass? navigation,
    RiverWindowClass? content,
  }) => RiverLayoutData(
    window: window ?? this.window,
    navigation: navigation ?? this.navigation,
    content: content ?? this.content,
  );

  RiverWindowClass operator [](RiverLayoutAspect aspect) => switch (aspect) {
    RiverLayoutAspect.window => window,
    RiverLayoutAspect.navigation => navigation,
    RiverLayoutAspect.content => content,
  };

  @override
  bool operator ==(Object other) =>
      other is RiverLayoutData &&
      other.window == window &&
      other.navigation == navigation &&
      other.content == content;

  @override
  int get hashCode => Object.hash(window, navigation, content);

  @override
  String toString() =>
      'RiverLayoutData(window: ${window.name}, '
      'navigation: ${navigation.name}, content: ${content.name})';
}

/// Publishes [RiverLayoutData] to descendants.
///
/// Dependents are notified only when the aspect they read changes, so reading
/// a class does not rebuild a widget on every pixel of a window resize.
/// Use [RiverLayoutScope] and [RiverContentScope] rather than creating this
/// widget directly.
class RiverLayout extends InheritedModel<RiverLayoutAspect> {
  const RiverLayout({super.key, required this.data, required super.child});

  final RiverLayoutData data;

  /// Returns the class for [aspect] and registers a dependency on it.
  ///
  /// Without an ancestor scope, classes are derived from [MediaQuery]. That
  /// fallback depends on the window size and rebuilds on every resize, so
  /// apps should install a [RiverLayoutScope] near the root.
  static RiverWindowClass of(BuildContext context, RiverLayoutAspect aspect) {
    final layout = InheritedModel.inheritFrom<RiverLayout>(
      context,
      aspect: aspect,
    );
    return (layout?.data ?? RiverLayoutData.fromMediaQuery(context))[aspect];
  }

  /// Returns all classes and registers a dependency on every aspect.
  static RiverLayoutData dataOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RiverLayout>()?.data ??
      RiverLayoutData.fromMediaQuery(context);

  @override
  bool updateShouldNotify(RiverLayout oldWidget) => data != oldWidget.data;

  @override
  bool updateShouldNotifyDependent(
    RiverLayout oldWidget,
    Set<RiverLayoutAspect> dependencies,
  ) => dependencies.any((aspect) => data[aspect] != oldWidget.data[aspect]);
}

/// Computes window and navigation classes from the window and publishes them.
///
/// Install one near the app root, below the [MediaQuery] provided by the app.
class RiverLayoutScope extends StatelessWidget {
  const RiverLayoutScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      RiverLayout(data: RiverLayoutData.fromMediaQuery(context), child: child);
}

/// Publishes the content class of the region given to [child].
///
/// The content class comes from this widget's width constraint. An unbounded
/// width inherits the enclosing content class.
class RiverContentScope extends StatelessWidget {
  const RiverContentScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final parent = RiverLayout.dataOf(context);
      final content = constraints.hasBoundedWidth
          ? RiverWindowClass.fromWidth(constraints.maxWidth)
          : parent.content;
      return RiverLayout(
        data: parent.copyWith(content: content),
        child: child,
      );
    },
  );
}

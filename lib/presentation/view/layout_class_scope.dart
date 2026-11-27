import 'package:flutter/widgets.dart';

/// Shares an application's layout class and notifies dependents only when
/// that class changes. The application decides how to classify its window.
final class LayoutClassScope<T extends Object> extends InheritedWidget {
  ///
  const LayoutClassScope({
    required this.layoutClass,
    required super.child,
    super.key,
  });

  /// The current layout class, such as an application-specific enum value.
  final T layoutClass;

  /// Looks up a layout class and subscribes to its changes.
  static T? maybeOf<T extends Object>(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LayoutClassScope<T>>()
      ?.layoutClass;

  ///
  @override
  bool updateShouldNotify(LayoutClassScope<T> oldWidget) =>
      layoutClass != oldWidget.layoutClass;
}

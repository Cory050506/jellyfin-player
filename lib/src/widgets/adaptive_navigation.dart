part of '../../main.dart';

/// Platform-specific page route factory
Route<T> adaptivePageRoute<T>({
  required WidgetBuilder builder,
  required String name,
  bool fullscreenDialog = false,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return cupertino.CupertinoPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
        settings: RouteSettings(name: name),
      );
    case TargetPlatform.windows:
      // Windows uses Material but with Fluent styling
      return MaterialPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
        settings: RouteSettings(name: name),
      );
    case TargetPlatform.android:
      return MaterialPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
        settings: RouteSettings(name: name),
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
      return MaterialPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
        settings: RouteSettings(name: name),
      );
  }
}

/// Convenience extension on NavigatorState for adaptive navigation
extension AdaptiveNavigator on NavigatorState {
  Future<T?> pushAdaptive<T extends Object?>({
    required WidgetBuilder builder,
    required String name,
    bool fullscreenDialog = false,
  }) {
    return push<T>(
      adaptivePageRoute(
        builder: builder,
        name: name,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  Future<T?> pushReplacementAdaptive<T extends Object?, TO extends Object?>({
    required WidgetBuilder builder,
    required String name,
    TO? result,
    bool fullscreenDialog = false,
  }) {
    return pushReplacement<T, TO>(
      adaptivePageRoute(
        builder: builder,
        name: name,
        fullscreenDialog: fullscreenDialog,
      ),
      result: result,
    );
  }
}

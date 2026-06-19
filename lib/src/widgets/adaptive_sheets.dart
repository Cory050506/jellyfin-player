part of '../../main.dart';

/// Show a platform-specific modal bottom sheet or dialog
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      // Use native Cupertino modal for iOS/macOS
      return cupertino.showCupertinoModalPopup<T>(
        context: context,
        builder: builder,
      );
    case TargetPlatform.windows:
      // Windows uses a native-style popup dialog
      return showDialog<T>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        builder: builder,
      );
    case TargetPlatform.android:
      // Android uses Material bottom sheet
      return showModalBottomSheet<T>(
        context: context,
        backgroundColor: backgroundColor ?? Colors.transparent,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        builder: builder,
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
      return showModalBottomSheet<T>(
        context: context,
        backgroundColor: backgroundColor ?? Colors.transparent,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        builder: builder,
      );
  }
}

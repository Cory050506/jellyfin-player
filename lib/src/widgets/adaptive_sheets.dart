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
      return cupertino.showCupertinoModalPopup<T>(
        context: context,
        builder: (ctx) => Material(
          color: Colors.transparent,
          child: builder(ctx),
        ),
      );
    case TargetPlatform.windows:
      // Windows uses a native-style popup dialog
      return showDialog<T>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        builder: builder,
      );
    case TargetPlatform.android:
      if (isScrollControlled) {
        return showDialog<T>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (dialogContext) {
            final size = MediaQuery.sizeOf(dialogContext);
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.86),
                child: builder(dialogContext),
              ),
            );
          },
        );
      }
      // Compact Android sheets use Material bottom sheets.
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

import 'package:flutter/material.dart';

/// Context menu option for native right-click menus
class ContextMenuOption {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isDivider;

  ContextMenuOption({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDivider = false,
  });

  static ContextMenuOption divider() => ContextMenuOption(
    label: '',
    onTap: () {},
    isDivider: true,
  );
}

/// Wraps a widget with native context menu support
class NativeContextMenuArea extends StatelessWidget {
  final Widget child;
  final List<ContextMenuOption> options;

  const NativeContextMenuArea({
    super.key,
    required this.child,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      child: child,
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final List<PopupMenuEntry<int>> items = [];
    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      if (option.isDivider) {
        items.add(const PopupMenuDivider());
      } else {
        items.add(
          PopupMenuItem<int>(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 20),
                  const SizedBox(width: 12),
                ],
                Text(option.label),
              ],
            ),
          ),
        );
      }
    }

    showMenu<int>(
      context: context,
      position: position,
      items: items,
    ).then((value) {
      if (value != null && value < options.length && !options[value].isDivider) {
        options[value].onTap();
      }
    });
  }
}

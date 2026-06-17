part of '../../main.dart';

// Per-platform native design systems, chosen at runtime so each build uses
// the controls that belong to its OS:
//   iOS/iPadOS -> cupertino_native (Liquid Glass UIKit)
//   Windows    -> fluent_ui (Fluent Design)
//   macOS      -> macos_ui (AppKit)
//   Android/other -> Material 3
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
bool get _isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Wraps a fluent_ui control so it has the required FluentTheme ancestor
/// without converting the whole app to a FluentApp.
Widget _fluentScope(Widget child) => fluent.FluentTheme(
  data: fluent.FluentThemeData.dark(),
  child: child,
);

/// Wraps a macos_ui control so it has the required MacosTheme ancestor.
Widget _macosScope(Widget child) => macos.MacosTheme(
  data: macos.MacosThemeData.dark(),
  child: child,
);

/// A settings row with a toggle, rendered with each platform's native switch.
class SettingSwitchTile extends StatelessWidget {
  const SettingSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    if (!_isIOS && !_isWindows && !_isMacOS) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      );
    }

    final Widget control;
    if (_isIOS) {
      control = CNSwitch(value: value, onChanged: onChanged);
    } else if (_isWindows) {
      control = _fluentScope(
        fluent.ToggleSwitch(checked: value, onChanged: onChanged),
      );
    } else {
      control = _macosScope(
        macos.MacosSwitch(value: value, onChanged: onChanged),
      );
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: control,
      onTap: () => onChanged(!value),
    );
  }
}

/// A slider rendered with each platform's native slider control.
class NativeSlider extends StatelessWidget {
  const NativeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(min, max).toDouble();
    final divisions = ((max - min) / step).round();

    if (_isIOS) {
      return CNSlider(
        value: clamped,
        min: min,
        max: max,
        step: step,
        onChanged: onChanged,
      );
    }
    if (_isWindows) {
      return _fluentScope(
        fluent.Slider(
          value: clamped,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
      );
    }
    if (_isMacOS) {
      return _macosScope(
        macos.MacosSlider(
          value: clamped,
          min: min,
          max: max,
          discrete: true,
          splits: divisions,
          onChanged: onChanged,
        ),
      );
    }
    return Slider(
      min: min,
      max: max,
      divisions: divisions,
      value: clamped,
      label: label,
      onChanged: onChanged,
    );
  }
}

/// A dropdown / picker rendered with each platform's native menu control.
class AdaptiveDropdown<T> extends StatelessWidget {
  const AdaptiveDropdown({
    super.key,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CNPopupMenuButton(
        buttonLabel: label(value),
        shrinkWrap: true,
        items: [
          for (final v in values) CNPopupMenuItem(label: label(v)),
        ],
        onSelected: (index) => onChanged(values[index]),
      );
    }
    if (_isWindows) {
      return _fluentScope(
        fluent.ComboBox<T>(
          value: value,
          items: [
            for (final v in values)
              fluent.ComboBoxItem<T>(value: v, child: Text(label(v))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }
    if (_isMacOS) {
      return _macosScope(
        macos.MacosPopupButton<T>(
          value: value,
          items: [
            for (final v in values)
              macos.MacosPopupMenuItem<T>(value: v, child: Text(label(v))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }
    return DropdownButton<T>(
      value: value,
      items: [
        for (final v in values)
          DropdownMenuItem<T>(value: v, child: Text(label(v))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// A button rendered with each platform's native button control.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.shrinkWrap = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  /// When true the button sizes to its content (for tight slots like a
  /// ListTile trailing); when false it can fill the available width.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CNButton(
        label: label,
        onPressed: onPressed,
        shrinkWrap: shrinkWrap,
        style: filled ? CNButtonStyle.filled : CNButtonStyle.plain,
      );
    }
    if (_isWindows) {
      final child = Text(label);
      return _fluentScope(
        filled
            ? fluent.FilledButton(onPressed: onPressed, child: child)
            : fluent.Button(onPressed: onPressed, child: child),
      );
    }
    if (_isMacOS) {
      return _macosScope(
        macos.PushButton(
          controlSize: macos.ControlSize.large,
          secondary: !filled,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    final child = Text(label);
    if (filled) {
      return icon != null
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            )
          : FilledButton(onPressed: onPressed, child: child);
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// A text field rendered with each platform's native text input.
class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? placeholder;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return cupertino.CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textAlign: textAlign,
        padding: const EdgeInsets.all(12),
        prefix: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(icon, size: 20),
              )
            : null,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      );
    }
    if (_isWindows) {
      return _fluentScope(
        fluent.TextBox(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textAlign: textAlign,
          prefix: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(icon, size: 18),
                )
              : null,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      );
    }
    if (_isMacOS) {
      return _macosScope(
        macos.MacosTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textAlign: textAlign,
          prefix: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(icon, size: 16),
                )
              : null,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      );
    }
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textAlign: textAlign,
      decoration: InputDecoration(
        labelText: placeholder,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

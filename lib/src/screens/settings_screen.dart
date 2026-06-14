part of '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppSettings> _settingsFuture;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _load();
  }

  Future<AppSettings> _load() async {
    final settings = await AppSettingsStore.load();
    _settings = settings;
    return settings;
  }

  Future<void> _update(AppSettings settings) async {
    setState(() => _settings = settings);
    await AppSettingsStore.save(settings);
  }

  Future<void> _reset() async {
    await AppSettingsStore.reset();
    setState(() {
      _settings = AppSettings.defaults;
      _settingsFuture = Future.value(AppSettings.defaults);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<AppSettings>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          final settings = _settings ?? snapshot.data;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              SettingsSection(
                title: 'Playback',
                children: [
                  SwitchListTile(
                    value: settings.directStream,
                    onChanged: (value) =>
                        _update(settings.copyWith(directStream: value)),
                    secondary: const Icon(Icons.route_rounded),
                    title: const Text('Prefer direct stream'),
                    subtitle: const Text(
                      'Keeps Jellyfin out of the browser/transcode path when possible.',
                    ),
                  ),
                  SwitchListTile(
                    value: settings.highBitrateCache,
                    onChanged: (value) =>
                        _update(settings.copyWith(highBitrateCache: value)),
                    secondary: const Icon(Icons.memory_rounded),
                    title: const Text('Large cache for 4K files'),
                    subtitle: Text(
                      '${settings.bufferSizeBytes ~/ 1024 ~/ 1024} MB mpv demuxer cache.',
                    ),
                  ),
                  SwitchListTile(
                    value: settings.hardwareDecoding,
                    onChanged: (value) =>
                        _update(settings.copyWith(hardwareDecoding: value)),
                    secondary: const Icon(Icons.developer_board_rounded),
                    title: const Text('Prefer hardware decoding'),
                    subtitle: const Text(
                      'Best for high-bitrate 4K and Android TV devices.',
                    ),
                  ),
                  EnumSettingTile<HdrMode>(
                    icon: Icons.hdr_on_rounded,
                    title: 'HDR handling',
                    value: settings.hdrMode,
                    values: HdrMode.values,
                    label: hdrModeLabel,
                    subtitle: hdrModeDescription(settings.hdrMode),
                    onChanged: (value) =>
                        _update(settings.copyWith(hdrMode: value)),
                  ),
                  EnumSettingTile<PlayerFit>(
                    icon: Icons.fit_screen_rounded,
                    title: 'Video fit',
                    value: settings.playerFit,
                    values: PlayerFit.values,
                    label: playerFitLabel,
                    subtitle: 'Default player scaling.',
                    onChanged: (value) =>
                        _update(settings.copyWith(playerFit: value)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SettingsSection(
                title: 'Tracks',
                children: [
                  EnumSettingTile<DefaultSubtitleMode>(
                    icon: Icons.subtitles_rounded,
                    title: 'Subtitle default',
                    value: settings.subtitleMode,
                    values: DefaultSubtitleMode.values,
                    label: subtitleModeLabel,
                    subtitle: 'You can still change subtitles during playback.',
                    onChanged: (value) =>
                        _update(settings.copyWith(subtitleMode: value)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('Subtitle offset'),
                    subtitle: Text('${settings.subtitleOffsetMs} ms'),
                    trailing: SizedBox(
                      width: 190,
                      child: Slider(
                        min: -5000,
                        max: 5000,
                        divisions: 40,
                        value: settings.subtitleOffsetMs.toDouble(),
                        label: '${settings.subtitleOffsetMs} ms',
                        onChanged: (value) => _update(
                          settings.copyWith(subtitleOffsetMs: value.round()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SettingsSection(
                title: 'About this build',
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('HDR note'),
                    subtitle: Text(
                      'HDR passthrough still depends on the OS, display, GPU, mpv backend, and the file. Keep OS HDR enabled on Windows and use a HDR-capable TV/display.',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Reset settings'),
                    subtitle: const Text('Restore the high-bitrate defaults.'),
                    trailing: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class EnumSettingTile<T> extends StatelessWidget {
  const EnumSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.subtitle,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) label;
  final String subtitle;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(label(item))),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

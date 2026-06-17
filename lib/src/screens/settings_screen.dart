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
                  SettingSwitchTile(
                    value: settings.directStream,
                    onChanged: (value) =>
                        _update(settings.copyWith(directStream: value)),
                    icon: Icons.route_rounded,
                    title: 'Prefer direct stream',
                    subtitle:
                        'Keeps Jellyfin out of the browser/transcode path when possible.',
                  ),
                  SettingSwitchTile(
                    value: settings.highBitrateCache,
                    onChanged: (value) =>
                        _update(settings.copyWith(highBitrateCache: value)),
                    icon: Icons.memory_rounded,
                    title: 'Large cache for 4K files',
                    subtitle:
                        '${settings.bufferSizeBytes ~/ 1024 ~/ 1024} MB mpv demuxer cache.',
                  ),
                  SettingSwitchTile(
                    value: settings.hardwareDecoding,
                    onChanged: (value) =>
                        _update(settings.copyWith(hardwareDecoding: value)),
                    icon: Icons.developer_board_rounded,
                    title: 'Prefer hardware decoding',
                    subtitle:
                        'Best for high-bitrate 4K and Android TV devices.',
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
                  _AudioLanguageTile(
                    value: settings.preferredAudioLanguage,
                    onChanged: (value) => _update(
                      settings.copyWith(preferredAudioLanguage: value),
                    ),
                  ),
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
                      child: NativeSlider(
                        min: -5000,
                        max: 5000,
                        step: 250,
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
                    trailing: AdaptiveButton(
                      label: 'Reset',
                      filled: false,
                      onPressed: _reset,
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
    return Material(
      color: AppColors.panel.withValues(alpha: 0.82),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white10),
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
      trailing: AdaptiveDropdown<T>(
        value: value,
        values: values,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}

class _AudioLanguageTile extends StatefulWidget {
  const _AudioLanguageTile({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_AudioLanguageTile> createState() => _AudioLanguageTileState();
}

class _AudioLanguageTileState extends State<_AudioLanguageTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.spatial_audio_rounded),
      title: const Text('Preferred audio language'),
      subtitle: const Text(
        'e.g. "eng", "en", "English" — overrides the file default when no track is manually chosen.',
      ),
      trailing: SizedBox(
        width: 130,
        child: AdaptiveTextField(
          controller: _controller,
          placeholder: 'Any',
          textAlign: TextAlign.center,
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
        ),
      ),
    );
  }
}

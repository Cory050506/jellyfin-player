part of '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.session});

  final JellyfinSession? session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppSettings> _settingsFuture;
  AppSettings? _settings;
  PackageInfo? _packageInfo;
  bool _launchAtStartup = false;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _load();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    if (isDesktopPlatform) {
      launchAtStartup.isEnabled().then((enabled) {
        if (mounted) setState(() => _launchAtStartup = enabled);
      });
    }
  }

  Future<AppSettings> _load() async {
    final settings = await AppSettingsStore.load();
    _settings = settings;
    return settings;
  }

  Future<void> _update(AppSettings settings) async {
    setState(() => _settings = settings);
    await AppSettingsStore.save(settings);
    // Keep the accent notifier in sync so the theme rebuilds immediately.
    AppColors.accentNotifier.value = settings.accentColor != null
        ? Color(settings.accentColor!)
        : AppColors.cyan;
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
      appBar: AppBar(
        title: const Text('Settings'),
        // Shift the back button clear of the floating macOS traffic lights.
        leadingWidth: _isMacOS ? 116 : null,
        leading: _isMacOS
            ? const Padding(
                padding: EdgeInsets.only(left: 70),
                child: BackButton(),
              )
            : null,
      ),
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
                title: 'Player',
                children: [
                  ListTile(
                    leading: const Icon(Icons.skip_next_rounded),
                    title: const Text('Skip duration'),
                    subtitle: Text('${settings.skipDurationSeconds}s per tap'),
                    trailing: SizedBox(
                      width: 190,
                      child: NativeSlider(
                        min: 5,
                        max: 90,
                        step: 5,
                        value: settings.skipDurationSeconds.toDouble(),
                        label: '${settings.skipDurationSeconds}s',
                        onChanged: (v) => _update(
                          settings.copyWith(skipDurationSeconds: v.round()),
                        ),
                      ),
                    ),
                  ),
                  SettingSwitchTile(
                    value: settings.autoPlayNextEpisode,
                    onChanged: (v) =>
                        _update(settings.copyWith(autoPlayNextEpisode: v)),
                    icon: Icons.queue_play_next_rounded,
                    title: 'Auto-play next episode',
                    subtitle: 'Shows a 15-second countdown at the end.',
                  ),
                  EnumSettingTile<ResumeBehavior>(
                    icon: Icons.history_rounded,
                    title: 'Resume behavior',
                    value: settings.resumeBehavior,
                    values: ResumeBehavior.values,
                    label: resumeBehaviorLabel,
                    subtitle: resumeBehaviorDescription(settings.resumeBehavior),
                    onChanged: (v) =>
                        _update(settings.copyWith(resumeBehavior: v)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SettingsSection(
                title: 'Appearance',
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_rounded),
                    title: const Text('Accent color'),
                    subtitle: const Text('Used for highlights and the nav bar tint.'),
                    trailing: _AccentColorPicker(
                      current: settings.accentColor != null
                          ? Color(settings.accentColor!)
                          : AppColors.cyan,
                      onChanged: (color) => _update(
                        settings.copyWith(
                          accentColor: color?.toARGB32(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.session != null) ...[
                const SizedBox(height: 18),
                SettingsSection(
                  title: 'Server',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_rounded),
                      title: const Text('Server URL'),
                      subtitle: Text(widget.session!.serverUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_rounded),
                      title: const Text('Signed in as'),
                      subtitle: Text(widget.session!.username),
                    ),
                  ],
                ),
              ],
              if (isDesktopPlatform) ...[
                const SizedBox(height: 18),
                SettingsSection(
                  title: 'System',
                  children: [
                    SettingSwitchTile(
                      value: _launchAtStartup,
                      onChanged: (value) async {
                        if (value) {
                          await launchAtStartup.enable();
                        } else {
                          await launchAtStartup.disable();
                        }
                        setState(() => _launchAtStartup = value);
                      },
                      icon: Icons.start_rounded,
                      title: 'Launch at login',
                      subtitle: 'Start the app automatically when you log in.',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SettingsSection(
                title: 'About this build',
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Version'),
                    subtitle: Text(_packageInfo != null
                        ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                        : '—'),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.macOS ||
                      defaultTargetPlatform == TargetPlatform.windows)
                    ListTile(
                      leading: const Icon(Icons.system_update_rounded),
                      title: const Text('Check for updates'),
                      subtitle: const Text('Checks the update feed for a newer version.'),
                      trailing: AdaptiveButton(
                        label: 'Check',
                        filled: false,
                        shrinkWrap: true,
                        onPressed: () => autoUpdater.checkForUpdates(),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Reset settings'),
                    subtitle: const Text('Restore the high-bitrate defaults.'),
                    trailing: AdaptiveButton(
                      label: 'Reset',
                      filled: false,
                      shrinkWrap: true,
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
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(6),
        ),
        child: AdaptiveDropdown<T>(
          value: value,
          values: values,
          label: label,
          onChanged: onChanged,
        ),
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

String resumeBehaviorLabel(ResumeBehavior b) => switch (b) {
  ResumeBehavior.ask => 'Ask',
  ResumeBehavior.alwaysResume => 'Always resume',
  ResumeBehavior.alwaysRestart => 'Always restart',
};

String resumeBehaviorDescription(ResumeBehavior b) => switch (b) {
  ResumeBehavior.ask => 'Show a prompt when there\'s a saved position.',
  ResumeBehavior.alwaysResume => 'Always pick up where you left off.',
  ResumeBehavior.alwaysRestart => 'Always play from the beginning.',
};

const _accentPresets = [
  Color(0xff00a4dc), // Jellyfin cyan (default)
  Color(0xff6366f1), // Indigo
  Color(0xffec4899), // Pink
  Color(0xfff59e0b), // Amber
  Color(0xff10b981), // Emerald
  Color(0xffef4444), // Red
  Color(0xffffffff), // White
];

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({required this.current, required this.onChanged});

  final Color current;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in _accentPresets)
          GestureDetector(
            onTap: () => onChanged(color == AppColors.cyan ? null : color),
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: current.toARGB32() == color.toARGB32()
                      ? Colors.white
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  if (current.toARGB32() == color.toARGB32())
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}


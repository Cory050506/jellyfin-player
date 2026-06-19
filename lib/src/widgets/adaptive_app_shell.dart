part of '../../main.dart';

/// Platform-specific app shell with top navigation bar
class AdaptiveAppShell extends StatefulWidget {
  const AdaptiveAppShell({
    super.key,
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<AdaptiveAppShell> createState() => _AdaptiveAppShellState();
}

class _AdaptiveAppShellState extends State<AdaptiveAppShell> {
  @override
  Widget build(BuildContext context) {
    // All platforms use the same top nav bar layout
    return _TopNavAppShell(
      session: widget.session,
      onSignedOut: widget.onSignedOut,
    );
  }
}

/// Main app shell with top navigation bar for all platforms
class _TopNavAppShell extends StatefulWidget {
  const _TopNavAppShell({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_TopNavAppShell> createState() => _TopNavAppShellState();
}

class _TopNavAppShellState extends State<_TopNavAppShell> {
  late final JellyfinClient _client = JellyfinClient(session: widget.session);
  Future<List<JellyfinLibrary>>? _librariesFuture;
  List<JellyfinLibrary> _allLibraries = const [];
  JellyfinLibrary? _selectedLibrary;
  Future<List<JellyfinItem>>? _itemsFuture;
  AppSettings _settings = AppSettings.defaults;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _settings = await AppSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _librariesFuture = _loadLibraries();
    });
  }

  List<JellyfinLibrary> _visible(List<JellyfinLibrary> all) {
    final hidden = _settings.hiddenLibraries.toSet();
    final byId = {for (final l in all) l.id: l};
    final result = <JellyfinLibrary>[];
    for (final id in _settings.libraryOrder) {
      final lib = byId[id];
      if (lib != null && !hidden.contains(id)) result.add(lib);
    }
    for (final l in all) {
      if (!_settings.libraryOrder.contains(l.id) && !hidden.contains(l.id)) {
        result.add(l);
      }
    }
    return result;
  }

  Future<List<JellyfinLibrary>> _loadLibraries() async {
    final libraries = await _client.getLibraries();
    _allLibraries = libraries;
    final visible = _visible(libraries);
    if (visible.isNotEmpty) {
      _selectedLibrary = visible.first;
      _itemsFuture = _client.getItems(visible.first);
    }
    return libraries;
  }

  void _selectLibrary(JellyfinLibrary library) {
    setState(() {
      _selectedLibrary = library;
      _itemsFuture = _client.getItems(library);
    });
  }

  Future<void> _saveSettings(AppSettings next) async {
    setState(() => _settings = next);
    await AppSettingsStore.save(next);
  }

  Future<void> _editLibraries() async {
    final result = await showAdaptiveSheet<({List<String> order, List<String> hidden})>(
      context: context,
      backgroundColor: AppColors.panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LibraryEditorSheet(
        libraries: _visible(_allLibraries) +
            _allLibraries
                .where((l) => _settings.hiddenLibraries.contains(l.id))
                .toList(),
        hidden: _settings.hiddenLibraries,
      ),
    );
    if (result == null) return;
    await _saveSettings(
      _settings.copyWith(
        libraryOrder: result.order,
        hiddenLibraries: result.hidden,
      ),
    );
    final visible = _visible(_allLibraries);
    if (_selectedLibrary == null ||
        !visible.any((l) => l.id == _selectedLibrary!.id)) {
      if (visible.isNotEmpty) {
        _selectLibrary(visible.first);
      } else {
        setState(() {
          _selectedLibrary = null;
          _itemsFuture = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JellyfinLibrary>>(
      future: _librariesFuture,
      builder: (context, snapshot) {
        if (_librariesFuture == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorPane(
            message: friendlyError(snapshot.error),
            onRetry: () => setState(() {
              _librariesFuture = _loadLibraries();
            }),
          );
        }
        final all = snapshot.data ?? [];
        if (all.isEmpty) {
          return const EmptyPane(
            icon: Icons.video_library_rounded,
            title: 'No libraries found',
            subtitle: 'This user does not have visible media libraries.',
          );
        }
        final visible = _visible(all);
        return Column(
          children: [
            // Top navigation bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.background,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // App branding
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.cyan,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Scrollable library tabs
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final lib in visible)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _NavTab(
                                  label: lib.name,
                                  icon: iconForLibrary(lib.collectionType),
                                  selected: lib.id == _selectedLibrary?.id,
                                  onTap: () => _selectLibrary(lib),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Menu button
                    PopupMenuButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 20),
                              SizedBox(width: 12),
                              Text('Edit Libraries'),
                            ],
                          ),
                          onTap: _editLibraries,
                        ),
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.settings_rounded, size: 20),
                              SizedBox(width: 12),
                              Text('Settings'),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).pushAdaptive<void>(
                              builder: (_) => const SettingsScreen(),
                              name: '/settings',
                            );
                          },
                        ),
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.logout_rounded, size: 20),
                              SizedBox(width: 12),
                              Text('Sign Out'),
                            ],
                          ),
                          onTap: widget.onSignedOut,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: ItemsView(
                client: _client,
                library: _selectedLibrary,
                itemsFuture: _itemsFuture,
                onRefresh: () {
                  final lib = _selectedLibrary;
                  if (lib != null) {
                    setState(() {
                      _itemsFuture = _client.getItems(lib);
                    });
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Individual navigation tab (pill-shaped button)
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.18)
                : AppColors.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.cyan : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.cyan : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

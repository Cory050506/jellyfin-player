part of '../../main.dart';

/// Platform-specific app shell that provides native navigation for each platform
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
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return _MacOSHomeShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.iOS:
        return _IOSHomeShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.windows:
        return _WindowsHomeShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.android:
        return HomeScreen(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return HomeScreen(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
    }
  }
}

/// macOS app shell with native-style sidebar navigation
class _MacOSHomeShell extends StatefulWidget {
  const _MacOSHomeShell({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_MacOSHomeShell> createState() => _MacOSHomeShellState();
}

class _MacOSHomeShellState extends State<_MacOSHomeShell> {
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
        return Row(
          children: [
            SizedBox(
              width: 280,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.cyan,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Jellyfin',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.session.username,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final lib in visible)
                            _SidebarItem(
                              icon: Icon(iconForLibrary(lib.collectionType)),
                              label: lib.name,
                              selected: lib.id == _selectedLibrary?.id,
                              onTap: () => _selectLibrary(lib),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          _SidebarButton(
                            icon: Icons.tune_rounded,
                            label: 'Edit Libraries',
                            onPressed: _editLibraries,
                          ),
                          _SidebarButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () {
                              Navigator.of(context).pushAdaptive<void>(
                                builder: (_) => const SettingsScreen(),
                                name: '/settings',
                              );
                            },
                          ),
                          _SidebarButton(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            onPressed: widget.onSignedOut,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

/// iOS app shell with split view on iPad and tab bar on iPhone
class _IOSHomeShell extends StatefulWidget {
  const _IOSHomeShell({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_IOSHomeShell> createState() => _IOSHomeShellState();
}

class _IOSHomeShellState extends State<_IOSHomeShell> {
  @override
  Widget build(BuildContext context) {
    final isIPad = MediaQuery.of(context).size.width > 600;
    if (isIPad) {
      return _IOSSplitView(
        session: widget.session,
        onSignedOut: widget.onSignedOut,
      );
    } else {
      return _IOSTabBar(
        session: widget.session,
        onSignedOut: widget.onSignedOut,
      );
    }
  }
}

/// iPad split view layout
class _IOSSplitView extends StatefulWidget {
  const _IOSSplitView({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_IOSSplitView> createState() => _IOSSplitViewState();
}

class _IOSSplitViewState extends State<_IOSSplitView> {
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
        return Row(
          children: [
            SizedBox(
              width: 280,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.cyan,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Jellyfin',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.session.username,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final lib in visible)
                            _SidebarItem(
                              icon: Icon(iconForLibrary(lib.collectionType)),
                              label: lib.name,
                              selected: lib.id == _selectedLibrary?.id,
                              onTap: () => _selectLibrary(lib),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          _SidebarButton(
                            icon: Icons.tune_rounded,
                            label: 'Edit Libraries',
                            onPressed: _editLibraries,
                          ),
                          _SidebarButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () {
                              Navigator.of(context).pushAdaptive<void>(
                                builder: (_) => const SettingsScreen(),
                                name: '/settings',
                              );
                            },
                          ),
                          _SidebarButton(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            onPressed: widget.onSignedOut,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

/// iPhone tab bar layout
class _IOSTabBar extends StatefulWidget {
  const _IOSTabBar({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_IOSTabBar> createState() => _IOSTabBarState();
}

class _IOSTabBarState extends State<_IOSTabBar> {
  late final JellyfinClient _client = JellyfinClient(session: widget.session);
  Future<List<JellyfinLibrary>>? _librariesFuture;
  List<JellyfinLibrary> _allLibraries = const [];
  JellyfinLibrary? _selectedLibrary;
  AppSettings _settings = AppSettings.defaults;
  int _selectedIndex = 0;

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
    }
    return libraries;
  }

  void _selectLibrary(JellyfinLibrary library) {
    setState(() {
      _selectedLibrary = library;
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
        return cupertino.CupertinoTabScaffold(
          tabBar: cupertino.CupertinoTabBar(
            items: [
              for (final lib in visible)
                cupertino.BottomNavigationBarItem(
                  icon: Icon(iconForLibrary(lib.collectionType)),
                  label: lib.name,
                ),
              const cupertino.BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
            onTap: (index) => setState(() => _selectedIndex = index),
            currentIndex: _selectedIndex,
          ),
          tabBuilder: (context, index) {
            if (index < visible.length) {
              final lib = visible[index];
              return cupertino.CupertinoTabView(
                builder: (context) => ItemsView(
                  client: _client,
                  library: lib,
                  itemsFuture: _client.getItems(lib),
                  onRefresh: () {},
                ),
              );
            } else {
              return cupertino.CupertinoTabView(
                builder: (context) => ListView(
                  children: [
                    cupertino.CupertinoListTile(
                      title: const Text('Edit Libraries'),
                      onTap: _editLibraries,
                    ),
                    cupertino.CupertinoListTile(
                      title: const Text('Settings'),
                      onTap: () {
                        Navigator.of(context).pushAdaptive<void>(
                          builder: (_) => const SettingsScreen(),
                          name: '/settings',
                        );
                      },
                    ),
                    cupertino.CupertinoListTile(
                      title: const Text('Sign Out'),
                      onTap: widget.onSignedOut,
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// Windows app shell with Fluent navigation rail
class _WindowsHomeShell extends StatefulWidget {
  const _WindowsHomeShell({
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_WindowsHomeShell> createState() => _WindowsHomeShellState();
}

class _WindowsHomeShellState extends State<_WindowsHomeShell> {
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
        return Row(
          children: [
            SizedBox(
              width: 280,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.cyan,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Jellyfin',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.session.username,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final lib in visible)
                            _SidebarItem(
                              icon: Icon(iconForLibrary(lib.collectionType)),
                              label: lib.name,
                              selected: lib.id == _selectedLibrary?.id,
                              onTap: () => _selectLibrary(lib),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          _SidebarButton(
                            icon: Icons.tune_rounded,
                            label: 'Edit Libraries',
                            onPressed: _editLibraries,
                          ),
                          _SidebarButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () {
                              Navigator.of(context).pushAdaptive<void>(
                                builder: (_) => const SettingsScreen(),
                                name: '/settings',
                              );
                            },
                          ),
                          _SidebarButton(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            onPressed: widget.onSignedOut,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.cyan.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: selected ? AppColors.cyan : Colors.white70,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

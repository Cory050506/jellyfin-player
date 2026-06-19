part of '../../main.dart';

/// Platform-specific app shell using native navigation for each platform
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
      case TargetPlatform.iOS:
        return _NativeIOSShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.macOS:
        return _NativeMacOSShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.windows:
        return _WindowsShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.android:
        return _AndroidShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return _DefaultShell(
          session: widget.session,
          onSignedOut: widget.onSignedOut,
        );
    }
  }
}

/// Native iOS app with bottom tab bar (CupertinoTabScaffold)
class _NativeIOSShell extends StatefulWidget {
  const _NativeIOSShell({required this.session, required this.onSignedOut});

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_NativeIOSShell> createState() => _NativeIOSShellState();
}

class _NativeIOSShellState extends State<_NativeIOSShell> {
  late final JellyfinClient _client = JellyfinClient(session: widget.session);
  Future<List<JellyfinLibrary>>? _librariesFuture;
  List<JellyfinLibrary> _allLibraries = const [];
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
    final future = _loadLibraries();
    setState(() => _librariesFuture = future);
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

  /// Libraries shown in the nav bar (max 4; 5th slot is always Settings).
  List<JellyfinLibrary> _navLibs(List<JellyfinLibrary> all) {
    final visible = _visible(all);
    final pinned = _settings.pinnedNavLibraries;
    if (pinned.isEmpty) return visible.take(4).toList();
    final byId = {for (final l in visible) l.id: l};
    return pinned
        .map((id) => byId[id])
        .whereType<JellyfinLibrary>()
        .take(4)
        .toList();
  }

  Future<List<JellyfinLibrary>> _loadLibraries() async {
    final libraries = await _client.getLibraries();
    _allLibraries = libraries;
    return libraries;
  }

  Future<void> _saveSettings(AppSettings next) async {
    setState(() => _settings = next);
    await AppSettingsStore.save(next);
  }

  Future<void> _editLibraries() async {
    final result =
        await showAdaptiveSheet<({List<String> order, List<String> hidden})>(
          context: context,
          backgroundColor: AppColors.panel,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => LibraryEditorSheet(
            libraries:
                _visible(_allLibraries) +
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
  }

  Future<void> _customizeNav(List<JellyfinLibrary> visible) async {
    final pinned = await showAdaptiveSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NavCustomizerSheet(
        libraries: visible,
        pinned: _settings.pinnedNavLibraries.isEmpty
            ? visible.take(4).map((l) => l.id).toList()
            : _settings.pinnedNavLibraries,
      ),
    );
    if (pinned == null) return;
    await _saveSettings(_settings.copyWith(pinnedNavLibraries: pinned));
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JellyfinLibrary>>(
      future: _librariesFuture,
      builder: (context, snapshot) {
        if (_librariesFuture == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const cupertino.CupertinoPageScaffold(
            child: Center(child: cupertino.CupertinoActivityIndicator()),
          );
        }
        if (snapshot.hasError) {
          return cupertino.CupertinoPageScaffold(
            child: ErrorPane(
              message: friendlyError(snapshot.error),
              onRetry: () => setState(() {
                _librariesFuture = _loadLibraries();
              }),
            ),
          );
        }
        final all = snapshot.data ?? [];
        if (all.isEmpty) {
          return const cupertino.CupertinoPageScaffold(
            child: EmptyPane(
              icon: Icons.video_library_rounded,
              title: 'No libraries found',
              subtitle: 'This user does not have visible media libraries.',
            ),
          );
        }

        final tabLibs = _navLibs(all);
        final visible = _visible(all);
        final tabs = [
          for (final lib in tabLibs)
            NativeGlassNavBarItem(
              label: lib.name,
              symbol: sfSymbolForLibrary(lib.collectionType),
            ),
          const NativeGlassNavBarItem(label: 'Settings', symbol: 'gear'),
        ];

        final pages = [
          for (final lib in tabLibs)
            ItemsView(
              client: _client,
              library: lib,
              itemsFuture: _client.getItems(lib),
              onRefresh: () {},
            ),
          // Settings tab
          cupertino.CupertinoPageScaffold(
            navigationBar: const cupertino.CupertinoNavigationBar(
              middle: Text('Settings'),
            ),
            child: SafeArea(
              child: ListView(
                children: [
                  // Libraries section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      'Libraries',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  cupertino.CupertinoListSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    children: [
                      cupertino.CupertinoListTile(
                        leading: const Icon(
                          cupertino.CupertinoIcons.square_grid_2x2,
                        ),
                        title: const Text('Edit Libraries'),
                        subtitle: const Text('Show, hide, and reorder'),
                        trailing: const cupertino.CupertinoListTileChevron(),
                        onTap: _editLibraries,
                      ),
                      cupertino.CupertinoListTile(
                        leading: const Icon(
                          cupertino.CupertinoIcons.rectangle_dock,
                        ),
                        title: const Text('Customize Navigation'),
                        subtitle: const Text('Choose up to 4 tabs'),
                        trailing: const cupertino.CupertinoListTileChevron(),
                        onTap: () => _customizeNav(visible),
                      ),
                    ],
                  ),
                  // App section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      'App',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  cupertino.CupertinoListSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    children: [
                      cupertino.CupertinoListTile(
                        leading: const Icon(cupertino.CupertinoIcons.settings),
                        title: const Text('Playback & Display'),
                        trailing: const cupertino.CupertinoListTileChevron(),
                        onTap: () {
                          Navigator.of(context).pushAdaptive<void>(
                            builder: (_) =>
                                SettingsScreen(session: widget.session),
                            name: '/settings',
                          );
                        },
                      ),
                    ],
                  ),
                  // Account section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  cupertino.CupertinoListSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    children: [
                      cupertino.CupertinoListTile(
                        leading: const Icon(
                          cupertino.CupertinoIcons.square_arrow_left,
                          color: cupertino.CupertinoColors.systemRed,
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: cupertino.CupertinoColors.systemRed,
                          ),
                        ),
                        onTap: widget.onSignedOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ];

        return Scaffold(
          extendBody: true,
          backgroundColor: AppColors.background,
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NativeGlassNavBar(
            tabs: tabs,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            tintColor: AppColors.cyan,
            fallback: cupertino.CupertinoTabBar(
              items: [
                for (final lib in tabLibs)
                  cupertino.BottomNavigationBarItem(
                    icon: Icon(iconForLibrary(lib.collectionType)),
                    label: lib.name,
                  ),
                const cupertino.BottomNavigationBarItem(
                  icon: Icon(cupertino.CupertinoIcons.gear),
                  label: 'Settings',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              activeColor: AppColors.cyan,
            ),
          ),
        );
      },
    );
  }
}

/// Native macOS app with sidebar navigation (macos_ui)
class _NativeMacOSShell extends StatefulWidget {
  const _NativeMacOSShell({required this.session, required this.onSignedOut});

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_NativeMacOSShell> createState() => _NativeMacOSShellState();
}

class _NativeMacOSShellState extends State<_NativeMacOSShell> {
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
    final future = _loadLibraries();
    setState(() => _librariesFuture = future);
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
    final result =
        await showAdaptiveSheet<({List<String> order, List<String> hidden})>(
          context: context,
          backgroundColor: AppColors.panel,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => LibraryEditorSheet(
            libraries:
                _visible(_allLibraries) +
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
              width: 200,
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
                          const SizedBox(height: 8),
                          Text(
                            'Jellyfin',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
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
                            _MacOSSidebarItem(
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
                          _MacOSSidebarButton(
                            icon: Icons.tune_rounded,
                            label: 'Edit',
                            onPressed: _editLibraries,
                          ),
                          _MacOSSidebarButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () {
                              Navigator.of(context).pushAdaptive<void>(
                                builder: (_) =>
                                    SettingsScreen(session: widget.session),
                                name: '/settings',
                              );
                            },
                          ),
                          _MacOSSidebarButton(
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

/// Windows app with sidebar
class _WindowsShell extends StatefulWidget {
  const _WindowsShell({required this.session, required this.onSignedOut});

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_WindowsShell> createState() => _WindowsShellState();
}

class _WindowsShellState extends State<_WindowsShell> {
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
    final future = _loadLibraries();
    setState(() => _librariesFuture = future);
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
    final result =
        await showAdaptiveSheet<({List<String> order, List<String> hidden})>(
          context: context,
          backgroundColor: AppColors.panel,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => LibraryEditorSheet(
            libraries:
                _visible(_allLibraries) +
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
              width: 200,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final lib in visible)
                          _SidebarItem(
                            icon: iconForLibrary(lib.collectionType),
                            label: lib.name,
                            selected: lib.id == _selectedLibrary?.id,
                            onTap: () => _selectLibrary(lib),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _SidebarButton(
                          icon: Icons.tune_rounded,
                          label: 'Edit',
                          onPressed: _editLibraries,
                        ),
                        _SidebarButton(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          onPressed: () {
                            Navigator.of(context).pushAdaptive<void>(
                              builder: (_) =>
                                  SettingsScreen(session: widget.session),
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

/// Android app with Material 3 bottom nav bar
class _AndroidShell extends StatefulWidget {
  const _AndroidShell({required this.session, required this.onSignedOut});

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<_AndroidShell> createState() => _AndroidShellState();
}

class _AndroidShellState extends State<_AndroidShell> {
  late final JellyfinClient _client = JellyfinClient(session: widget.session);
  Future<List<JellyfinLibrary>>? _librariesFuture;
  List<JellyfinLibrary> _allLibraries = const [];
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
    final future = _loadLibraries();
    setState(() => _librariesFuture = future);
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

  List<JellyfinLibrary> _navLibs(List<JellyfinLibrary> all) {
    final visible = _visible(all);
    final pinned = _settings.pinnedNavLibraries;
    if (pinned.isEmpty) return visible.take(4).toList();
    final byId = {for (final l in visible) l.id: l};
    return pinned
        .map((id) => byId[id])
        .whereType<JellyfinLibrary>()
        .take(4)
        .toList();
  }

  Future<List<JellyfinLibrary>> _loadLibraries() async {
    final libraries = await _client.getLibraries();
    _allLibraries = libraries;
    return libraries;
  }

  Future<void> _saveSettings(AppSettings next) async {
    setState(() => _settings = next);
    await AppSettingsStore.save(next);
  }

  Future<void> _editLibraries() async {
    final result =
        await showAdaptiveSheet<({List<String> order, List<String> hidden})>(
          context: context,
          backgroundColor: AppColors.panel,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => LibraryEditorSheet(
            libraries:
                _visible(_allLibraries) +
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
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    return FutureBuilder<List<JellyfinLibrary>>(
      future: _librariesFuture,
      builder: (context, snapshot) {
        if (_librariesFuture == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorPane(
              message: friendlyError(snapshot.error),
              onRetry: () {
                setState(() {
                  _librariesFuture = _loadLibraries();
                });
              },
            ),
          );
        }
        final all = snapshot.data ?? [];
        if (all.isEmpty) {
          return const Scaffold(
            body: EmptyPane(
              icon: Icons.video_library_rounded,
              title: 'No libraries found',
              subtitle: 'This user does not have visible media libraries.',
            ),
          );
        }

        final tabLibs = _navLibs(all);

        final pages = [
          for (final lib in tabLibs)
            ItemsView(
              client: _client,
              library: lib,
              itemsFuture: _client.getItems(lib),
              onRefresh: () {},
            ),
          // Settings page
          Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('Edit Libraries'),
                  subtitle: const Text('Show, hide, and reorder'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editLibraries,
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Playback & Display'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushAdaptive<void>(
                    builder: (_) => SettingsScreen(session: widget.session),
                    name: '/settings',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: widget.onSignedOut,
                ),
              ],
            ),
          ),
        ];

        return Scaffold(
          extendBody: true,
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            indicatorColor: accent.withValues(alpha: 0.2),
            backgroundColor: AppColors.background.withValues(alpha: 0.92),
            destinations: [
              for (final lib in tabLibs)
                NavigationDestination(
                  icon: Icon(iconForLibrary(lib.collectionType)),
                  label: lib.name,
                ),
              const NavigationDestination(
                icon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Default fallback
class _DefaultShell extends StatelessWidget {
  const _DefaultShell({required this.session, required this.onSignedOut});

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(session: session, onSignedOut: onSignedOut);
  }
}

/// macOS sidebar item
class _MacOSSidebarItem extends StatelessWidget {
  const _MacOSSidebarItem({
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
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

class _MacOSSidebarButton extends StatelessWidget {
  const _MacOSSidebarButton({
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
      padding: const EdgeInsets.only(bottom: 6),
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
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
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

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.cyan.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppColors.cyan : Colors.white70),
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
      padding: const EdgeInsets.only(bottom: 6),
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
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet for choosing which libraries appear in the iOS nav bar (max 4).
class _NavCustomizerSheet extends StatefulWidget {
  const _NavCustomizerSheet({required this.libraries, required this.pinned});

  final List<JellyfinLibrary> libraries;
  final List<String> pinned;

  @override
  State<_NavCustomizerSheet> createState() => _NavCustomizerSheetState();
}

class _NavCustomizerSheetState extends State<_NavCustomizerSheet> {
  late List<String> _pinned;

  @override
  void initState() {
    super.initState();
    _pinned = List.of(widget.pinned);
  }

  void _toggle(String id) {
    setState(() {
      if (_pinned.contains(id)) {
        _pinned.remove(id);
      } else if (_pinned.length < 4) {
        _pinned.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customize Navigation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Choose up to 4  •  ${_pinned.length}/4 selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  cupertino.CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(_pinned),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final lib in widget.libraries)
              cupertino.CupertinoListTile(
                leading: Icon(iconForLibrary(lib.collectionType)),
                title: Text(lib.name),
                trailing: cupertino.CupertinoCheckbox(
                  value: _pinned.contains(lib.id),
                  onChanged: (_pinned.contains(lib.id) || _pinned.length < 4)
                      ? (_) => _toggle(lib.id)
                      : null,
                  activeColor: AppColors.cyan,
                ),
                onTap: (_pinned.contains(lib.id) || _pinned.length < 4)
                    ? () => _toggle(lib.id)
                    : null,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

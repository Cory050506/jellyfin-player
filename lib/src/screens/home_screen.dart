part of '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onSignedOut,
  });

  final JellyfinSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  /// Applies the user's order and hidden set to the raw server list.
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

  void _toggleCollapsed() {
    _saveSettings(
      _settings.copyWith(sidebarCollapsed: !_settings.sidebarCollapsed),
    );
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
    // If the selected library was hidden, fall back to the first visible one.
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
    return Scaffold(
      body: FutureBuilder<List<JellyfinLibrary>>(
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
          return SafeArea(
            child: Padding(
              // Clear the floating macOS traffic-light buttons.
              padding: EdgeInsets.only(top: _isMacOS ? 28 : 0),
              child: Row(
                children: [
                  MediaSidebar(
                    username: widget.session.username,
                    libraries: visible,
                    selectedLibrary: _selectedLibrary,
                    collapsed: _settings.sidebarCollapsed,
                    onToggleCollapsed: _toggleCollapsed,
                    onEditLibraries: _editLibraries,
                    onLibrarySelected: _selectLibrary,
                    onRefresh: () {
                      setState(() {
                        if (_selectedLibrary == null) {
                          _librariesFuture = _loadLibraries();
                        } else {
                          _itemsFuture = _client.getItems(_selectedLibrary!);
                        }
                      });
                    },
                    onSignedOut: widget.onSignedOut,
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
              ),
            ),
          );
        },
      ),
    );
  }
}

class MediaSidebar extends StatelessWidget {
  const MediaSidebar({
    super.key,
    required this.username,
    required this.libraries,
    required this.selectedLibrary,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onEditLibraries,
    required this.onLibrarySelected,
    required this.onRefresh,
    required this.onSignedOut,
  });

  final String username;
  final List<JellyfinLibrary> libraries;
  final JellyfinLibrary? selectedLibrary;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onEditLibraries;
  final ValueChanged<JellyfinLibrary> onLibrarySelected;
  final VoidCallback onRefresh;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    final expanded = !collapsed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: expanded ? 248 : 88,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.cyan,
                    size: 30,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jellyfin',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Libraries',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: onEditLibraries,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final library in libraries)
                  SidebarButton(
                    icon: iconForLibrary(library.collectionType),
                    label: library.name,
                    selected: library.id == selectedLibrary?.id,
                    expanded: expanded,
                    onPressed: () => onLibrarySelected(library),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SidebarButton(
                  icon: collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  label: 'Collapse',
                  selected: false,
                  expanded: expanded,
                  onPressed: onToggleCollapsed,
                ),
                SidebarButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  selected: false,
                  expanded: expanded,
                  onPressed: onRefresh,
                ),
                SidebarButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: false,
                  expanded: expanded,
                  onPressed: () {
                    Navigator.of(context).pushAdaptive<void>(
                      builder: (_) => const SettingsScreen(),
                      name: '/settings',
                    );
                  },
                ),
                SidebarButton(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  selected: false,
                  expanded: expanded,
                  onPressed: onSignedOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that lets the user reorder and hide/show libraries.
class LibraryEditorSheet extends StatefulWidget {
  const LibraryEditorSheet({
    super.key,
    required this.libraries,
    required this.hidden,
  });

  final List<JellyfinLibrary> libraries;
  final List<String> hidden;

  @override
  State<LibraryEditorSheet> createState() => _LibraryEditorSheetState();
}

class _LibraryEditorSheetState extends State<LibraryEditorSheet> {
  late List<JellyfinLibrary> _order;
  late Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.libraries);
    _hidden = widget.hidden.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit libraries',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                AdaptiveButton(
                  label: 'Done',
                  shrinkWrap: true,
                  onPressed: () => Navigator.of(context).pop((
                    order: _order.map((l) => l.id).toList(),
                    hidden: _hidden.toList(),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Drag to reorder. Tap the eye to hide a library from the sidebar.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Material(
                color: Colors.transparent,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _order.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _order.removeAt(oldIndex);
                      _order.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final lib = _order[index];
                    final hidden = _hidden.contains(lib.id);
                    return ListTile(
                      key: ValueKey(lib.id),
                      leading: Icon(iconForLibrary(lib.collectionType)),
                      title: Text(
                        lib.name,
                        style: TextStyle(
                          color: hidden ? Colors.white38 : Colors.white,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: hidden ? 'Show' : 'Hide',
                            icon: Icon(
                              hidden
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: hidden ? Colors.white38 : AppColors.cyan,
                            ),
                            onPressed: () => setState(() {
                              if (hidden) {
                                _hidden.remove(lib.id);
                              } else {
                                _hidden.add(lib.id);
                              }
                            }),
                          ),
                          const Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class SidebarButton extends StatefulWidget {
  const SidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  State<SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<SidebarButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused || _hovered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.cyan.withValues(alpha: 0.18)
                : active
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppColors.cyan : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.expanded ? 12 : 0,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: widget.expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.selected ? AppColors.cyan : Colors.white70,
                    ),
                    if (widget.expanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.selected
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: widget.selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

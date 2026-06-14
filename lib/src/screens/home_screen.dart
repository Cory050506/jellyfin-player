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
  late Future<List<JellyfinLibrary>> _librariesFuture;
  JellyfinLibrary? _selectedLibrary;
  Future<List<JellyfinItem>>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _librariesFuture = _loadLibraries();
  }

  Future<List<JellyfinLibrary>> _loadLibraries() async {
    final libraries = await _client.getLibraries();
    if (libraries.isNotEmpty) {
      _selectedLibrary = libraries.first;
      _itemsFuture = _client.getItems(libraries.first);
    }
    return libraries;
  }

  void _selectLibrary(JellyfinLibrary library) {
    setState(() {
      _selectedLibrary = library;
      _itemsFuture = _client.getItems(library);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<JellyfinLibrary>>(
        future: _librariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorPane(
              message: friendlyError(snapshot.error),
              onRetry: () =>
                  setState(() => _librariesFuture = _loadLibraries()),
            );
          }
          final libraries = snapshot.data ?? [];
          if (libraries.isEmpty) {
            return const EmptyPane(
              icon: Icons.video_library_rounded,
              title: 'No libraries found',
              subtitle: 'This user does not have visible media libraries.',
            );
          }
          return SafeArea(
            child: Row(
              children: [
                MediaSidebar(
                  username: widget.session.username,
                  libraries: libraries,
                  selectedLibrary: _selectedLibrary,
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
                  ),
                ),
              ],
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
    required this.onLibrarySelected,
    required this.onRefresh,
    required this.onSignedOut,
  });

  final String username;
  final List<JellyfinLibrary> libraries;
  final JellyfinLibrary? selectedLibrary;
  final ValueChanged<JellyfinLibrary> onLibrarySelected;
  final VoidCallback onRefresh;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      width: wide ? 248 : 88,
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
              mainAxisAlignment: wide
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
                if (wide) ...[
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
                if (wide)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Text(
                      'Libraries',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                for (final library in libraries)
                  SidebarButton(
                    icon: iconForLibrary(library.collectionType),
                    label: library.name,
                    selected: library.id == selectedLibrary?.id,
                    expanded: wide,
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
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  selected: false,
                  expanded: wide,
                  onPressed: onRefresh,
                ),
                SidebarButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: false,
                  expanded: wide,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                SidebarButton(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  selected: false,
                  expanded: wide,
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

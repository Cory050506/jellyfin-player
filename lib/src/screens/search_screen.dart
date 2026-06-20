part of '../../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.client, this.isTab = false});
  final JellyfinClient client;
  // true when embedded as a nav tab (no back button, no autofocus on mount)
  final bool isTab;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<JellyfinItem>? _results;
  String? _error;
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (!widget.isTab) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(query.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.client.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTab) return _buildTabLayout(context);
    return _buildPushedLayout(context);
  }

  // ── iOS tab layout — App Store style ──────────────────────────────────────

  Widget _buildTabLayout(BuildContext context) {
    final results = _results;
    return cupertino.CupertinoPageScaffold(
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          cupertino.CupertinoSliverNavigationBar(
            largeTitle: const Text('Search'),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: cupertino.CupertinoSearchTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Movies, shows, episodes…',
                onChanged: _onQueryChanged,
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) _search(q.trim());
                },
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: cupertino.CupertinoActivityIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(child: ErrorPane(message: _error!))
          else if (results == null)
            const SliverFillRemaining(
              child: EmptyPane(
                icon: Icons.search_rounded,
                title: 'Search your library',
                subtitle: 'Type a movie, show, or episode name.',
              ),
            )
          else if (results.isEmpty)
            const SliverFillRemaining(
              child: EmptyPane(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Try a different search term.',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${results.length} result${results.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              sliver: _resultsGrid(results),
            ),
          ],
        ],
      ),
    );
  }

  // ── pushed layout (Android / macOS / Windows + iOS when navigated to) ─────

  Widget _buildPushedLayout(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search movies, shows, episodes…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            filled: false,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (q) {
            if (q.trim().isNotEmpty) _search(q.trim());
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: _clear,
            ),
        ],
      ),
      body: _buildPushedBody(results),
    );
  }

  Widget _buildPushedBody(List<JellyfinItem>? results) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorPane(message: _error!);
    if (results == null) {
      return const EmptyPane(
        icon: Icons.search_rounded,
        title: 'Search your library',
        subtitle: 'Type a movie, show, or episode name.',
      );
    }
    if (results.isEmpty) {
      return const EmptyPane(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different search term.',
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${results.length} result${results.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          sliver: _resultsGrid(results),
        ),
      ],
    );
  }

  // ── shared grid ───────────────────────────────────────────────────────────

  SliverGrid _resultsGrid(List<JellyfinItem> results) {
    final crossAxisCount =
        (MediaQuery.of(context).size.width / 200).floor().clamp(2, 8);
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return MediaTile(
          item: item,
          imageUrl: widget.client.imageUrl(item),
          onTap: () {
            Navigator.of(context).pushAdaptive<void>(
              builder: (_) => ItemScreen(client: widget.client, item: item),
              name: '/item/${item.id}',
            );
          },
        );
      },
    );
  }
}

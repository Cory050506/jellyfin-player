import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const JellyfinPlayerApp());
}

class JellyfinPlayerApp extends StatelessWidget {
  const JellyfinPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00a4dc),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101417),
        cardTheme: CardThemeData(
          color: const Color(0xff182025),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xff151b20),
        ),
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<JellyfinSession?> _sessionFuture = SessionStore.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JellyfinSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final session = snapshot.data;
        if (session == null) {
          return LoginScreen(onSignedIn: _openHome);
        }
        return HomeScreen(session: session, onSignedOut: _signOut);
      },
    );
  }

  void _openHome(JellyfinSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(session: session, onSignedOut: _signOut),
      ),
    );
  }

  Future<void> _signOut() async {
    await SessionStore.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onSignedIn: _openHome)),
      (_) => false,
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final ValueChanged<JellyfinSession> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController(text: 'http://');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Jellyfin Player',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Direct, simple playback for the big files.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        prefixIcon: Icon(Icons.dns_rounded),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                      obscureText: true,
                      onSubmitted: (_) => _signIn(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: const Text('Connect'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final normalizedServer = normalizeServerUrl(_serverController.text);
      final client = JellyfinClient(baseUrl: normalizedServer);
      final session = await client.authenticate(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await SessionStore.save(session);
      widget.onSignedIn(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

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
      _itemsFuture = _client.getItems(libraries.first.id);
    }
    return libraries;
  }

  void _selectLibrary(JellyfinLibrary library) {
    setState(() {
      _selectedLibrary = library;
      _itemsFuture = _client.getItems(library.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin Player'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                if (_selectedLibrary == null) {
                  _librariesFuture = _loadLibraries();
                } else {
                  _itemsFuture = _client.getItems(_selectedLibrary!.id);
                }
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignedOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
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
          return Row(
            children: [
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 880,
                selectedIndex: libraries.indexWhere(
                  (item) => item.id == _selectedLibrary?.id,
                ),
                onDestinationSelected: (index) =>
                    _selectLibrary(libraries[index]),
                destinations: [
                  for (final library in libraries)
                    NavigationRailDestination(
                      icon: Icon(iconForLibrary(library.collectionType)),
                      selectedIcon: Icon(
                        iconForLibrary(library.collectionType),
                      ),
                      label: Text(library.name),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ItemsView(
                  client: _client,
                  library: _selectedLibrary,
                  itemsFuture: _itemsFuture,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ItemsView extends StatelessWidget {
  const ItemsView({
    super.key,
    required this.client,
    required this.library,
    required this.itemsFuture,
  });

  final JellyfinClient client;
  final JellyfinLibrary? library;
  final Future<List<JellyfinItem>>? itemsFuture;

  @override
  Widget build(BuildContext context) {
    final future = itemsFuture;
    if (library == null || future == null) {
      return const EmptyPane(
        icon: Icons.movie_filter_rounded,
        title: 'Pick a library',
        subtitle: 'Choose a media library to start browsing.',
      );
    }
    return FutureBuilder<List<JellyfinItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorPane(message: friendlyError(snapshot.error));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return EmptyPane(
            icon: Icons.folder_open_rounded,
            title: '${library!.name} is empty',
            subtitle: 'Nothing was returned from this library.',
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  library!.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.62,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return MediaTile(
                    item: item,
                    imageUrl: client.imageUrl(item),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ItemScreen(client: client, item: item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.imageUrl,
    required this.onTap,
  });

  final JellyfinItem item;
  final Uri imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xff202a31)),
                      child: Icon(
                        Icons.movie_rounded,
                        size: 44,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  if (item.type == 'Series')
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.tv_rounded, color: Colors.white),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  Future<List<JellyfinItem>>? _childrenFuture;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'Series' ||
        widget.item.type == 'Season' ||
        widget.item.type == 'Folder') {
      _childrenFuture = widget.client.getItems(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlayable = widget.item.isPlayable;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final poster = AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.client
                            .imageUrl(widget.item, width: 700)
                            .toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xff202a31),
                          child: Icon(
                            Icons.movie_rounded,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      if (widget.item.overview.isNotEmpty)
                        Text(
                          widget.item.overview,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.45),
                        ),
                      const SizedBox(height: 24),
                      if (isPlayable)
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  client: widget.client,
                                  item: widget.item,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: SizedBox(width: 220, child: poster)),
                        const SizedBox(height: 24),
                        details,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 260, child: poster),
                      const SizedBox(width: 28),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_childrenFuture != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              sliver: FutureBuilder<List<JellyfinItem>>(
                future: _childrenFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final children = snapshot.data ?? [];
                  return SliverList.separated(
                    itemCount: children.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return ListTile(
                        tileColor: const Color(0xff182025),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          child.isPlayable
                              ? Icons.play_circle_rounded
                              : Icons.folder_rounded,
                        ),
                        title: Text(child.name),
                        subtitle: Text(child.subtitle),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => child.isPlayable
                                  ? PlayerScreen(
                                      client: widget.client,
                                      item: child,
                                    )
                                  : ItemScreen(
                                      client: widget.client,
                                      item: child,
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    unawaited(_openMedia());
  }

  Future<void> _openMedia() async {
    try {
      final url = widget.client.streamUrl(widget.item);
      await _player.open(Media(url.toString()), play: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.item.name),
      ),
      body: Center(
        child: _error == null
            ? Video(controller: _controller)
            : ErrorPane(message: _error!, dark: true),
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.white54),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({
    super.key,
    required this.message,
    this.onRetry,
    this.dark = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: dark ? Colors.white : null),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class JellyfinClient {
  JellyfinClient({JellyfinSession? session, String? baseUrl})
    : session = session,
      baseUrl = baseUrl ?? session!.serverUrl;

  static const clientName = 'Jellyfin Player';
  static const clientVersion = '0.1.0';

  final JellyfinSession? session;
  final String baseUrl;

  Map<String, String> get _headers {
    final deviceId = session?.deviceId ?? 'setup-device';
    final tokenPart = session == null
        ? ''
        : ', Token="${session!.accessToken}"';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Emby-Authorization':
          'MediaBrowser Client="$clientName", Device="Flutter", DeviceId="$deviceId", Version="$clientVersion"$tokenPart',
    };
  }

  Future<JellyfinSession> authenticate({
    required String username,
    required String password,
  }) async {
    final deviceId = await SessionStore.deviceId();
    final response = await http.post(
      _uri('/Users/AuthenticateByName'),
      headers: {
        ..._headers,
        'X-Emby-Authorization':
            'MediaBrowser Client="$clientName", Device="Flutter", DeviceId="$deviceId", Version="$clientVersion"',
      },
      body: jsonEncode({'Username': username, 'Pw': password}),
    );
    final body = decodeResponse(response);
    return JellyfinSession(
      serverUrl: baseUrl,
      accessToken: body['AccessToken'] as String,
      userId: body['User']['Id'] as String,
      username: body['User']['Name'] as String? ?? username,
      deviceId: deviceId,
    );
  }

  Future<List<JellyfinLibrary>> getLibraries() async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Views'),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinLibrary.fromJson(item as Map<String, dynamic>))
        .where((library) => library.collectionType != 'playlists')
        .toList();
  }

  Future<List<JellyfinItem>> getItems(String parentId) async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Items', {
        'ParentId': parentId,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields':
            'Overview,PrimaryImageAspectRatio,MediaSources,Genres,RunTimeTicks,ProductionYear',
        'Limit': '200',
      }),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Uri imageUrl(JellyfinItem item, {int width = 420}) {
    final query = <String, String>{
      'fillWidth': '$width',
      'quality': '90',
      if (item.imageTag != null) 'tag': item.imageTag!,
      if (session != null) 'api_key': session!.accessToken,
    };
    return _uri('/Items/${item.id}/Images/Primary', query);
  }

  Uri streamUrl(JellyfinItem item) {
    return _uri('/Videos/${item.id}/stream', {
      'static': 'true',
      'api_key': session!.accessToken,
    });
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = [
      if (base.path.isNotEmpty) base.path.replaceAll(RegExp(r'/$'), ''),
      path,
    ].join();
    return base.replace(path: normalizedPath, queryParameters: query);
  }
}

class JellyfinSession {
  const JellyfinSession({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.deviceId,
  });

  final String serverUrl;
  final String accessToken;
  final String userId;
  final String username;
  final String deviceId;

  Map<String, String> toJson() => {
    'serverUrl': serverUrl,
    'accessToken': accessToken,
    'userId': userId,
    'username': username,
    'deviceId': deviceId,
  };

  static JellyfinSession fromJson(Map<String, dynamic> json) {
    return JellyfinSession(
      serverUrl: json['serverUrl'] as String,
      accessToken: json['accessToken'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      deviceId: json['deviceId'] as String,
    );
  }
}

class SessionStore {
  static const _sessionKey = 'session';
  static const _deviceIdKey = 'deviceId';

  static Future<JellyfinSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionKey);
    if (value == null) {
      return null;
    }
    return JellyfinSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  static Future<void> save(JellyfinSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) {
      return existing;
    }
    final generated = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }
}

class JellyfinLibrary {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    required this.collectionType,
  });

  final String id;
  final String name;
  final String collectionType;

  static JellyfinLibrary fromJson(Map<String, dynamic> json) {
    return JellyfinLibrary(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Library',
      collectionType: json['CollectionType'] as String? ?? '',
    );
  }
}

class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    required this.overview,
    required this.productionYear,
    required this.runTimeTicks,
    required this.imageTag,
  });

  final String id;
  final String name;
  final String type;
  final String overview;
  final int? productionYear;
  final int? runTimeTicks;
  final String? imageTag;

  bool get isPlayable =>
      type == 'Movie' || type == 'Episode' || type == 'Video';

  String get subtitle {
    final parts = [
      if (productionYear != null) productionYear.toString(),
      if (durationLabel.isNotEmpty) durationLabel,
      type,
    ];
    return parts.join('  ');
  }

  String get durationLabel {
    final ticks = runTimeTicks;
    if (ticks == null || ticks <= 0) {
      return '';
    }
    final duration = Duration(microseconds: ticks ~/ 10);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static JellyfinItem fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'] as Map<String, dynamic>? ?? {};
    return JellyfinItem(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Untitled',
      type: json['Type'] as String? ?? '',
      overview: json['Overview'] as String? ?? '',
      productionYear: json['ProductionYear'] as int?,
      runTimeTicks: json['RunTimeTicks'] as int?,
      imageTag: tags['Primary'] as String?,
    );
  }
}

Map<String, dynamic> decodeResponse(http.Response response) {
  final body = response.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }
  final message =
      body['Message'] as String? ??
      'Jellyfin returned HTTP ${response.statusCode}.';
  throw JellyfinException(message);
}

String normalizeServerUrl(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'/$'), '');
  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
      ? trimmed
      : 'http://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    throw const JellyfinException('Enter a valid Jellyfin server URL.');
  }
  return withScheme;
}

String friendlyError(Object? error) {
  if (error is JellyfinException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return 'The server took too long to respond.';
  }
  return 'Something went wrong: $error';
}

IconData iconForLibrary(String type) {
  return switch (type) {
    'movies' => Icons.movie_rounded,
    'tvshows' => Icons.tv_rounded,
    'music' => Icons.music_note_rounded,
    'books' => Icons.menu_book_rounded,
    _ => Icons.video_library_rounded,
  };
}

class JellyfinException implements Exception {
  const JellyfinException(this.message);

  final String message;

  @override
  String toString() => message;
}

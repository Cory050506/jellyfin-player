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
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: AppColors.control,
          prefixIconColor: Colors.white60,
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SessionGate(),
    );
  }
}

class AppColors {
  static const background = Color(0xff070b0f);
  static const panel = Color(0xff111820);
  static const panelRaised = Color(0xff17212b);
  static const control = Color(0xff101820);
  static const cyan = Color(0xff00a4dc);
  static const mint = Color(0xff00d6a3);
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff05080c), Color(0xff0b1820), Color(0xff080b10)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 820;
                    final form = _LoginPanel(
                      busy: _busy,
                      error: _error,
                      serverController: _serverController,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      onSignIn: _signIn,
                    );
                    if (compact) {
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _BrandPanel(compact: true),
                            const SizedBox(height: 20),
                            form,
                          ],
                        ),
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(child: _BrandPanel()),
                        const SizedBox(width: 24),
                        SizedBox(width: 430, child: form),
                      ],
                    );
                  },
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

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 0 : 520),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff102533), Color(0xff091017)],
        ),
        border: Border.all(color: Colors.white10),
      ),
      padding: EdgeInsets.all(compact ? 22 : 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.42)),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 46,
              color: AppColors.cyan,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Jellyfin Player',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A clean player shell built around direct playback, local servers, and TV-friendly browsing.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 28),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FeaturePill(icon: Icons.hd_rounded, label: '4K ready'),
                _FeaturePill(icon: Icons.tv_rounded, label: 'TV first'),
                _FeaturePill(icon: Icons.speed_rounded, label: 'Native media'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.busy,
    required this.error,
    required this.serverController,
    required this.usernameController,
    required this.passwordController,
    required this.onSignIn,
  });

  final bool busy;
  final String? error;
  final TextEditingController serverController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use your Jellyfin server URL and account.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: serverController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
                obscureText: true,
                onSubmitted: (_) => onSignIn(),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: busy
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
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.mint),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
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
                        _itemsFuture = _client.getItems(_selectedLibrary!.id);
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
        final featured = items.first;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 24, 10),
              sliver: SliverToBoxAdapter(
                child: LibraryHero(
                  library: library!,
                  item: featured,
                  backdropUrl: client.backdropUrl(featured, width: 1400),
                  posterUrl: client.imageUrl(featured, width: 360),
                  onPlay: featured.isPlayable
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlayerScreen(client: client, item: featured),
                            ),
                          );
                        }
                      : null,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ItemScreen(client: client, item: featured),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'All media',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${items.length} items',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 214,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.6,
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

class LibraryHero extends StatelessWidget {
  const LibraryHero({
    super.key,
    required this.library,
    required this.item,
    required this.backdropUrl,
    required this.posterUrl,
    required this.onOpen,
    this.onPlay,
  });

  final JellyfinLibrary library;
  final JellyfinItem item;
  final Uri backdropUrl;
  final Uri posterUrl;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            backdropUrl.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.network(
              posterUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.panelRaised),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xee070b0f),
                  Color(0x99070b0f),
                  Color(0x22070b0f),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xcc070b0f), Color(0x00070b0f)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.panelRaised,
                        child: Icon(
                          Icons.movie_rounded,
                          color: Colors.white54,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        library.name,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (item.overview.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Text(
                            item.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (onPlay != null)
                            FilledButton.icon(
                              onPressed: onPlay,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          OutlinedButton.icon(
                            onPressed: onOpen,
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MediaTile extends StatefulWidget {
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
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      child: AnimatedScale(
        scale: active ? 1.035 : 1,
        duration: const Duration(milliseconds: 140),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppColors.cyan : Colors.white10,
              width: _focused ? 2 : 1,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: AppColors.panel,
              child: InkWell(
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.panelRaised,
                                    Color(0xff0b1117),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.movie_rounded,
                                size: 44,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.center,
                                  colors: [
                                    Color(0x99000000),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.item.isPlayable
                                          ? Icons.play_arrow_rounded
                                          : iconForLibrary(widget.item.type),
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.item.durationLabel.isEmpty
                                          ? widget.item.type
                                          : widget.item.durationLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
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
}

class DetailBackdrop extends StatelessWidget {
  const DetailBackdrop({
    super.key,
    required this.backdropUrl,
    required this.posterUrl,
    required this.item,
    required this.onPlay,
  });

  final Uri backdropUrl;
  final Uri posterUrl;
  final JellyfinItem item;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            backdropUrl.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.network(
              posterUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.panelRaised),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xee070b0f),
                  Color(0xaa070b0f),
                  Color(0x33070b0f),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xdd070b0f), Color(0x00070b0f)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.panelRaised,
                        child: Icon(
                          Icons.movie_rounded,
                          color: Colors.white54,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (item.overview.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            item.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (onPlay != null) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                          onPressed: onPlay,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: DetailBackdrop(
                backdropUrl: widget.client.backdropUrl(
                  widget.item,
                  width: 1600,
                ),
                posterUrl: widget.client.imageUrl(widget.item, width: 700),
                item: widget.item,
                onPlay: isPlayable
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              client: widget.client,
                              item: widget.item,
                            ),
                          ),
                        );
                      }
                    : null,
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
            'Overview,PrimaryImageAspectRatio,MediaSources,Genres,RunTimeTicks,ProductionYear,BackdropImageTags',
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

  Uri backdropUrl(JellyfinItem item, {int width = 1200}) {
    final query = <String, String>{
      'fillWidth': '$width',
      'quality': '88',
      if (item.backdropTag != null) 'tag': item.backdropTag!,
      if (session != null) 'api_key': session!.accessToken,
    };
    return _uri('/Items/${item.id}/Images/Backdrop/0', query);
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
    required this.backdropTag,
  });

  final String id;
  final String name;
  final String type;
  final String overview;
  final int? productionYear;
  final int? runTimeTicks;
  final String? imageTag;
  final String? backdropTag;

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
    final backdropTags = json['BackdropImageTags'] as List<dynamic>? ?? [];
    return JellyfinItem(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Untitled',
      type: json['Type'] as String? ?? '',
      overview: json['Overview'] as String? ?? '',
      productionYear: json['ProductionYear'] as int?,
      runTimeTicks: json['RunTimeTicks'] as int?,
      imageTag: tags['Primary'] as String?,
      backdropTag: backdropTags.isEmpty ? null : backdropTags.first as String?,
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

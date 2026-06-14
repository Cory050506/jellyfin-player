part of '../../main.dart';

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

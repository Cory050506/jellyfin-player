part of '../main.dart';

class JellyfinPlayerApp extends StatelessWidget {
  const JellyfinPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppColors.accentNotifier,
      builder: (context, accent, _) {
        return MaterialApp(
          title: 'Jellyfin Player',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
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
      },
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

  static final ValueNotifier<Color> accentNotifier = ValueNotifier(cyan);

  static Color get accent => accentNotifier.value;
}

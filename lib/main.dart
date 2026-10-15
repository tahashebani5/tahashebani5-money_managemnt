import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/accountPages/selectAccount.dart';
import 'services/Database_Services.dart';
import 'widgets/appLockGate.dart';
import 'widgets/commonWidgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    currencySymbol = await DatabaseHelper().getSetting('currency') ?? currencySymbol;
    await loadCustomCategories();
  } catch (_) {
    // Keep the defaults; the app still opens
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
      // Keeps the primary colour close to the brand teal instead of a muted tone
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    // Coloured header in light mode; a calm dark header in dark mode
    final appBarBackground = dark ? scheme.surfaceContainer : scheme.primary;
    final appBarForeground = dark ? scheme.onSurface : scheme.onPrimary;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Tajawal',
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: appBarForeground,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محفظتي',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      // Arabic UI: right-to-left layout and Arabic system texts
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Optional PIN lock over every screen (off unless enabled in settings)
      builder: (context, child) => AppLockGate(child: child!),
      home: Selectaccount(),
    );
  }
}

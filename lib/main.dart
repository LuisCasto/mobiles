import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'application/app_controller.dart';
import 'data/auth_repository.dart';
import 'data/cloud_repository.dart';
import 'data/local_store.dart';
import 'data/open_food_facts_repository.dart';
import 'presentation/navigation.dart';
import 'presentation/screens/about_screen.dart';
import 'presentation/screens/account_screen.dart';
import 'presentation/screens/create_screen.dart';
import 'presentation/screens/detail_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/lookup_screen.dart';
import 'presentation/screens/scanner_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/theme.dart';
import 'presentation/widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

Future<AppController> bootstrap() async {
  final preferences = await SharedPreferences.getInstance();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? client;
  if (url.isNotEmpty != key.isNotEmpty) {
    throw const AppException(
      'Configura SUPABASE_URL y SUPABASE_ANON_KEY juntos.',
    );
  }
  if (url.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: key);
    client = Supabase.instance.client;
  }
  final controller = AppController(
    entriesRepository: LocalEntryRepository(preferences),
    products: OpenFoodFactsRepository(),
    preferences: preferences,
    auth: client == null
        ? LocalAuthRepository(preferences)
        : SupabaseAuthRepository(client),
    cloud: client == null ? null : CloudRepository(client),
  );
  // Local corruption is handled by HomeScreen's retryable FutureBuilder.
  try {
    await controller.initialize();
  } on AppException {
    /* Keep the original local data. */
  }
  return controller;
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<AppController> _ready = bootstrap();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasData) return UBuyApp(controller: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: snapshot.hasError
              ? EmptyState(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: 'No pudimos iniciar uBuy',
                  description:
                      'Revisa el acceso al almacenamiento del navegador y la configuración del proyecto.',
                  action: FilledButton(
                    onPressed: () => setState(() => _ready = bootstrap()),
                    child: const Text('Reintentar'),
                  ),
                )
              : const Center(child: CupertinoActivityIndicator()),
        ),
      );
    },
  );
}

class UBuyApp extends StatelessWidget {
  const UBuyApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'uBuy · Elige con más información',
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        themeMode: controller.themeMode,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: AppRoutes.home,
        routes: {
          AppRoutes.home: (_) => const HomeScreen(),
          AppRoutes.search: (_) => const SearchScreen(),
          AppRoutes.scanner: (_) => const ScannerScreen(),
          AppRoutes.account: (_) => const AccountScreen(),
          AppRoutes.about: (_) => const AboutScreen(),
        },
        onGenerateRoute: (settings) {
          final args = settings.arguments;
          final Widget screen;
          switch (settings.name) {
            case AppRoutes.detail when args is ProductDetailArguments:
              screen = DetailScreen(arguments: args);
            case AppRoutes.lookup when args is String:
              screen = LookupScreen(barcode: args);
            case AppRoutes.create:
              screen = CreateScreen(barcode: args is String ? args : null);
            default:
              screen = const Scaffold(
                body: EmptyState(
                  icon: CupertinoIcons.compass,
                  title: 'Página no encontrada',
                  description: 'Vuelve al inicio para continuar explorando.',
                ),
              );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => screen,
          );
        },
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || media.accessibleNavigation,
            ),
            child: child!,
          );
        },
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubuy/application/app_controller.dart';
import 'package:ubuy/data/auth_repository.dart';
import 'package:ubuy/data/local_store.dart';
import 'package:ubuy/data/open_food_facts_repository.dart';
import 'package:ubuy/domain/product.dart';
import 'package:ubuy/domain/recommendation.dart';
import 'package:ubuy/main.dart';
import 'package:ubuy/presentation/navigation.dart';
import 'package:ubuy/presentation/widgets/healthier_alternatives.dart';
import 'package:ubuy/presentation/widgets/recommendation_rating.dart';
import 'package:ubuy/presentation/widgets/scan_landing.dart';

const sample = Product(
  barcode: '7501234567890',
  name: 'Avena de prueba',
  brand: 'Mi marca',
  ingredients: 'Avena integral.',
  nutriScore: 'a',
  nova: 1,
);

class FakeProducts implements ProductRepository {
  FakeProducts({this.suggestions = const []});
  final List<Product> suggestions;
  int alternativeRequests = 0;
  @override
  Future<AlternativeSearchResult> alternativesFor(Product product) async {
    alternativeRequests++;
    return AlternativeSearchResult(
      categoryTag: 'en:yogurts',
      products: suggestions,
    );
  }

  @override
  Future<Product?> findByBarcode(String barcode) async => sample;
  @override
  Future<List<Product>> search(String query, {int page = 1}) async => [sample];
}

Future<AppController> testController({ProductRepository? products}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    entriesRepository: LocalEntryRepository(preferences),
    products: products ?? FakeProducts(),
    auth: LocalAuthRepository(preferences),
    preferences: preferences,
  );
  await controller.initialize();
  return controller;
}

void main() {
  testWidgets(
    'Una mala nota muestra alternativas navegables sin repetir consultas al guardar',
    (tester) async {
      const original = Product(
        barcode: '7501234567890',
        name: 'Postre muy azucarado',
        nutriScore: 'e',
        nova: 4,
        categoryTags: ['en:yogurts'],
      );
      const alternative = Product(
        barcode: '7501234567891',
        name: 'Yogur natural de prueba',
        nutriScore: 'a',
        nova: 1,
        categoryTags: ['en:yogurts'],
      );
      final products = FakeProducts(suggestions: [alternative]);
      final app = await testController(products: products);
      addTearDown(app.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(UBuyApp(controller: app));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(
            AppRoutes.detail,
            arguments: const ProductDetailArguments(original),
          );
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byType(RecommendationRating),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Poco recomendable'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(HealthierAlternatives),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Yogur natural de prueba'), findsOneWidget);
      expect(find.text('uBuy 10/10'), findsOneWidget);
      expect(products.alternativeRequests, 1);
      await app.saveProduct(original);
      await tester.pumpAndSettle();
      expect(products.alternativeRequests, 1);
      await tester.ensureVisible(find.text('Yogur natural de prueba'));
      await tester.tap(find.text('Yogur natural de prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Yogur natural de prueba'), findsOneWidget);
      expect(find.byType(HealthierAlternatives), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Escanear abre primero y Resumen conserva el dashboard en móvil y escritorio',
    (tester) async {
      final app = await testController();
      addTearDown(app.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(1440, 900),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(UBuyApp(key: ValueKey(size), controller: app));
        await tester.pumpAndSettle();
        final primaryScan = find.byKey(const ValueKey('primary-scan-button'));
        expect(primaryScan, findsOneWidget);
        expect(
          tester.getSize(primaryScan).shortestSide,
          greaterThanOrEqualTo(160),
        );
        expect(
          find.text('Lo bueno empieza\npor saber qué compras.'),
          findsNothing,
        );
        final mobile = size.width < 1040;
        await tester.tap(
          mobile
              ? find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('Resumen'),
                )
              : find.widgetWithText(ListTile, 'Resumen'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Lo bueno empieza\npor saber qué compras.'),
          findsOneWidget,
        );
        expect(primaryScan, findsNothing);
        await tester.tap(
          mobile
              ? find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('Escanear'),
                )
              : find.widgetWithText(ListTile, 'Escanear'),
        );
        await tester.pumpAndSettle();
        expect(primaryScan, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'El botón principal abre el escáner y lleva el código a la consulta',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: ScanLanding()),
          routes: {
            AppRoutes.scanner: (context) => Scaffold(
              appBar: AppBar(title: const Text('Escáner de prueba')),
              body: TextButton(
                onPressed: () => Navigator.pop(context, sample.barcode),
                child: const Text('Devolver código'),
              ),
            ),
            AppRoutes.lookup: (context) => Scaffold(
              appBar: AppBar(title: const Text('Consulta de prueba')),
              body: Text(ModalRoute.of(context)!.settings.arguments as String),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Escáner de prueba'), findsNothing);
      final primaryScan = find.byKey(const ValueKey('primary-scan-button'));
      await tester.tap(primaryScan);
      await tester.pumpAndSettle();
      expect(find.text('Escáner de prueba'), findsOneWidget);
      await tester.tap(find.text('Devolver código'));
      await tester.pumpAndSettle();
      expect(find.text('Consulta de prueba'), findsOneWidget);
      expect(find.text(sample.barcode), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(primaryScan).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Buscar, abrir el detalle y guardar un favorito', (tester) async {
    final app = await testController();
    addTearDown(app.dispose);
    await tester.pumpWidget(UBuyApp(controller: app));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRoutes.search);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'avena');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Avena de prueba'), findsOneWidget);
    await tester.ensureVisible(find.text('Avena de prueba'));
    await tester.tap(find.text('Avena de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del producto'), findsOneWidget);
    expect(find.text('Otra perspectiva, con IA'), findsNothing);
    await tester.tap(find.byTooltip('Añadir a favoritos'));
    await tester.pumpAndSettle();
    expect(app.entries, hasLength(1));
    expect(app.entries.single.favorite, isTrue);
    final stored = await app.entriesRepository.load('guest');
    expect(stored.single.product.barcode, sample.barcode);
    expect(stored.single.favorite, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cuenta, búsqueda y formulario caben en un teléfono', (
    tester,
  ) async {
    final app = await testController();
    addTearDown(app.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UBuyApp(controller: app));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (final route in [
      AppRoutes.account,
      AppRoutes.search,
      AppRoutes.create,
    ]) {
      navigator.pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Una nueva aportación se guarda y abre su detalle', (
    tester,
  ) async {
    final app = await testController();
    addTearDown(app.dispose);
    await tester.pumpWidget(UBuyApp(controller: app));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.create);
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.scrollUntilVisible(field, 200, scrollable: scrollable);
      await tester.enterText(field, value);
    }

    await fill('Código de barras *', '7501234567890');
    await fill('Nombre del producto *', 'Mi producto nuevo');
    await fill('Ingredientes *', 'Avena, agua.');
    final save = find.widgetWithText(FilledButton, 'Guardar aportación');
    await tester.scrollUntilVisible(save, 200, scrollable: scrollable);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Detalle del producto'), findsOneWidget);
    expect(app.entries.single.product.name, 'Mi producto nuevo');
    expect(app.entries.single.product.source, ProductSource.contribution);
    expect(tester.takeException(), isNull);
  });
}

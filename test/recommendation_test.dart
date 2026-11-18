import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubuy/data/local_store.dart';
import 'package:ubuy/data/open_food_facts_repository.dart';
import 'package:ubuy/domain/product.dart';
import 'package:ubuy/domain/recommendation.dart';

Product food(
  String code, {
  String grade = 'b',
  int? nova = 1,
  List<String> categories = const ['en:yogurts'],
}) => Product(
  barcode: code,
  name: 'Producto $code',
  nutriScore: grade,
  nova: nova,
  categoryTags: categories,
);

Map<String, dynamic> offFood(
  String code, {
  String grade = 'b',
  int? nova = 1,
  List<String> categories = const ['en:yogurts'],
}) => {
  'code': code,
  'product_name': 'Producto $code',
  'nutriscore_grade': grade,
  'nova_group': ?nova,
  'categories_tags': categories,
  'categories_hierarchy': categories,
};

void main() {
  const evaluator = NutritionEvaluator();
  group('Escala uBuy', () {
    test('Mantiene la escala 1–10, el orden y el umbral de alternativas', () {
      final scores = <int>[];
      for (final grade in ['a', 'b', 'c', 'd', 'e']) {
        final standard = evaluator.evaluate(food('original', grade: grade));
        final ultra = evaluator.evaluate(
          food('original', grade: grade, nova: 4),
        );
        scores.add(standard.score!);
        expect(ultra.score, standard.score! - 1);
        expect(ultra.score, inInclusiveRange(1, 10));
        expect(standard.suggestsAlternatives, standard.score! <= 5);
        expect(ultra.suggestsAlternatives, ultra.score! <= 5);
      }
      expect(scores, orderedEquals([10, 8, 6, 4, 2]));
    });

    test('No asigna cero a datos ausentes y distingue una nota parcial', () {
      for (final grade in ['', 'unknown', 'not-applicable']) {
        final unknown = evaluator.evaluate(
          food('unknown', grade: grade, nova: 4),
        );
        expect(unknown.score, isNull);
        expect(unknown.suggestsAlternatives, isFalse);
      }
      final partial = evaluator.evaluate(
        food('partial', grade: 'b', nova: null),
      );
      expect(partial.score, 8);
      expect(
        partial.observations.any((text) => text.contains('parcial')),
        isTrue,
      );
      expect(evaluator.scoreFor(food('invalid-nova', nova: 99)), 8);
    });

    test('No cuenta los nutrientes dos veces ni penaliza alérgenos', () {
      const product = Product(
        barcode: 'original',
        name: 'Ejemplo',
        nutriScore: 'b',
        nova: 1,
        nutrients: {'sugars_100g': 50, 'salt_100g': 10},
        allergens: ['milk'],
      );
      expect(evaluator.scoreFor(product), evaluator.scoreFor(food('other')));
    });
  });

  group('Selección de alternativas', () {
    test(
      'Excluye productos ajenos, repetidos, inferiores y sin datos comparables',
      () {
        final original = food('original', grade: 'e', nova: 4);
        final selected = const AlternativeSelector().select(original, [
          food('original', grade: 'a'),
          food('other-category', grade: 'a', categories: ['en:waters']),
          food('missing-score', grade: ''),
          food('missing-nova', nova: null),
          food('still-low', grade: 'c', nova: 4),
          food('better', grade: 'b'),
          food('better', grade: 'b'),
          food('best', grade: 'a'),
          food('third', grade: 'c'),
          food('fourth', grade: 'c'),
        ], categoryTag: 'en:yogurts');
        expect(selected.map((p) => p.barcode), ['best', 'better', 'fourth']);
        expect(selected.every((p) => evaluator.scoreFor(p)! >= 6), isTrue);
      },
    );

    test(
      'Permite mejorar procesamiento con igual Nutri-Score, sin sugerir empeoramientos',
      () {
        final original = food('original', grade: 'c', nova: 4);
        final result = const AlternativeSelector().select(original, [
          food('less-processed', grade: 'c', nova: 1),
          food('worse-grade', grade: 'd'),
        ], categoryTag: 'en:yogurts');
        expect(result.single.barcode, 'less-processed');
        expect(
          const AlternativeSelector().select(
            food('good', grade: 'a'),
            result,
            categoryTag: 'en:yogurts',
          ),
          isEmpty,
        );
      },
    );
  });

  group('Categorías y contrato de Open Food Facts', () {
    test(
      'Lee la jerarquía, conserva categorías y acepta registros antiguos',
      () {
        final product = Product.fromOff(
          offFood(
            '7501234567890',
            categories: [
              'en:foods',
              'en:dairies',
              'en:yogurts',
              'fr:Une-marque',
            ],
          ),
        );
        expect(product.comparisonCategories, ['en:yogurts']);
        expect(
          Product.fromJson(product.toJson()).categoryTags,
          product.categoryTags,
        );
        final oldJson = product.toJson()..remove('categoryTags');
        expect(Product.fromJson(oldJson).categoryTags, isEmpty);
      },
    );

    test(
      'Filtra por categoría, limita campos y reutiliza resultados en caché',
      () async {
        var requests = 0;
        final repo = OpenFoodFactsRepository(
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, '/api/v2/search');
            expect(
              request.url.queryParameters['categories_tags'],
              'en:yogurts',
            );
            expect(request.url.queryParameters['sort_by'], 'nutriscore_score');
            expect(
              request.url.queryParameters['fields'],
              contains('categories_hierarchy'),
            );
            return http.Response(
              jsonEncode({
                'products': [offFood('better')],
              }),
              200,
            );
          }),
        );
        addTearDown(repo.dispose);
        final original = food('original', grade: 'd', nova: 4);
        expect(
          (await repo.alternativesFor(original)).products.single.barcode,
          'better',
        );
        await repo.alternativesFor(original);
        expect(requests, 1);
      },
    );

    test(
      'Recupera categorías de registros antiguos sin cambiar sus datos locales',
      () async {
        final paths = <String>[];
        final repo = OpenFoodFactsRepository(
          client: MockClient((request) async {
            paths.add(request.url.path);
            return http.Response(
              jsonEncode(
                request.url.path.startsWith('/api/v3/')
                    ? {'product': offFood('7501234567890', grade: 'd', nova: 4)}
                    : {
                        'products': [offFood('better')],
                      },
              ),
              200,
            );
          }),
        );
        addTearDown(repo.dispose);
        final old = food('7501234567890', grade: 'd', nova: 4, categories: []);
        expect((await repo.alternativesFor(old)).products, hasLength(1));
        expect(paths, ['/api/v3/product/7501234567890.json', '/api/v2/search']);
        expect(old.categoryTags, isEmpty);
      },
    );

    test(
      'No hace solicitudes para una buena nota ni para una aportación sin categoría',
      () async {
        final repo = OpenFoodFactsRepository(
          client: MockClient((_) async => fail('Consulta innecesaria')),
        );
        addTearDown(repo.dispose);
        expect(
          (await repo.alternativesFor(food('good', grade: 'a'))).products,
          isEmpty,
        );
        const contribution = Product(
          barcode: '7501234567890',
          name: 'Local',
          nutriScore: 'e',
          source: ProductSource.contribution,
        );
        expect((await repo.alternativesFor(contribution)).categoryTag, isNull);
      },
    );

    test(
      'Un límite 429 permite reintentar y no queda guardado como una lista vacía',
      () async {
        var requests = 0;
        final repo = OpenFoodFactsRepository(
          client: MockClient((_) async {
            requests++;
            return requests == 1
                ? http.Response('{}', 429)
                : http.Response(
                    jsonEncode({
                      'products': [offFood('better')],
                    }),
                    200,
                  );
          }),
        );
        addTearDown(repo.dispose);
        final original = food('original', grade: 'd');
        await expectLater(
          repo.alternativesFor(original),
          throwsA(isA<AppException>()),
        );
        expect((await repo.alternativesFor(original)).products, hasLength(1));
      },
    );
  });
}

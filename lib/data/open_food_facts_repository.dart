import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/product.dart';
import '../domain/recommendation.dart';
import 'local_store.dart';

abstract interface class ProductRepository {
  Future<List<Product>> search(String query, {int page = 1});
  Future<Product?> findByBarcode(String barcode);
  Future<AlternativeSearchResult> alternativesFor(Product product);
}

class OpenFoodFactsRepository implements ProductRepository {
  OpenFoodFactsRepository({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const fields =
      'code,product_name,product_name_es,brands,quantity,image_front_url,image_url,ingredients_text,ingredients_text_es,nutriscore_grade,nova_group,nutriments,allergens_tags,categories_tags,categories_hierarchy';
  static const host = String.fromEnvironment(
    'OFF_HOST',
    defaultValue: 'world.openfoodfacts.org',
  );
  final Map<String, List<Product>> _searchCache = {};
  final Map<String, Product?> _productCache = {};
  final Map<String, List<Product>> _categoryCache = {};

  @override
  Future<AlternativeSearchResult> alternativesFor(Product product) async {
    if (!const NutritionEvaluator().evaluate(product).suggestsAlternatives) {
      return const AlternativeSearchResult();
    }
    var categories = product.comparisonCategories;
    // Entries saved before categories were introduced remain readable.
    if (categories.isEmpty && product.source == ProductSource.openFoodFacts) {
      final refreshed = await findByBarcode(product.barcode);
      categories = refreshed?.comparisonCategories ?? [];
    }
    if (categories.isEmpty) return const AlternativeSearchResult();
    for (final category in categories) {
      var candidates = _categoryCache[category];
      if (candidates == null) {
        final data = await _get(
          Uri.https(host, '/api/v2/search', {
            'categories_tags': category,
            'sort_by': 'nutriscore_score',
            'page_size': '24',
            'page': '1',
            'fields': fields,
            'lc': 'es',
            'app_name': 'uBuy',
          }),
        );
        candidates = (data?['products'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Product.fromOff)
            .toList();
        _categoryCache[category] = candidates;
      }
      final better = const AlternativeSelector().select(
        product,
        candidates,
        categoryTag: category,
      );
      if (better.isNotEmpty) {
        return AlternativeSearchResult(categoryTag: category, products: better);
      }
    }
    return AlternativeSearchResult(categoryTag: categories.first);
  }

  @override
  Future<List<Product>> search(String query, {int page = 1}) async {
    final key = '${query.trim().toLowerCase()}:$page';
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    final data = await _get(
      Uri.https(host, '/cgi/search.pl', {
        'search_terms': query.trim(),
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'page': '$page',
        'fields': fields,
        'lc': 'es',
        'app_name': 'uBuy',
      }),
    );
    final products = (data?['products'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Product.fromOff)
        .where((p) => p.barcode.isNotEmpty)
        .toList();
    _searchCache[key] = products;
    return products;
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      throw const AppException(
        'Escribe un código de barras de 8 a 14 dígitos.',
      );
    }
    if (_productCache.containsKey(barcode)) return _productCache[barcode];
    final data = await _get(
      Uri.https(host, '/api/v3/product/$barcode.json', {
        'fields': fields,
        'lc': 'es',
        'app_name': 'uBuy',
      }),
    );
    final raw = data?['product'];
    final product = raw is Map<String, dynamic> ? Product.fromOff(raw) : null;
    _productCache[barcode] = product;
    return product;
  }

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              // Browsers control User-Agent; app_name identifies the web client.
              if (!kIsWeb) 'User-Agent': 'uBuy/1.0 (Flutter educational app)',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 404) return null;
      if (response.statusCode == 429) {
        throw const AppException(
          'Open Food Facts recibió demasiadas consultas. Espera un minuto antes de buscar otra vez.',
        );
      }
      if (response.statusCode != 200) {
        throw AppException(
          'Open Food Facts no está disponible (${response.statusCode}). Puedes consultar tu bitácora o intentarlo después.',
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        'La consulta tardó demasiado. Revisa tu conexión e intenta otra vez.',
      );
    } catch (_) {
      throw const AppException(
        'No se pudo conectar con Open Food Facts. Revisa tu conexión; tus productos guardados siguen disponibles.',
      );
    }
  }

  void dispose() => _client.close();
}

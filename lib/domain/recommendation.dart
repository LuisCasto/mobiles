import 'product.dart';

class Recommendation {
  const Recommendation(
    this.title,
    this.summary,
    this.observations, {
    this.score,
  });
  final String title;
  final String summary;
  final List<String> observations;
  final int? score;

  bool get suggestsAlternatives => score != null && score! <= 5;
  String get ratingLabel => score == null
      ? 'Sin puntuación'
      : score! >= 8
      ? 'Perfil favorable'
      : score! >= 6
      ? 'Opción intermedia'
      : score! >= 4
      ? 'Mejor comparar'
      : 'Poco recomendable';
}

/// A transparent uBuy heuristic, not an official OFF score or a clinical model.
/// Nutrients are not scored twice: they are already part of Nutri-Score.
class NutritionEvaluator {
  const NutritionEvaluator();

  static const methodology =
      'Índice propio de uBuy: Nutri-Score A=10, B=8, C=6, D=4, E=2. '
      'Se resta 1 punto cuando NOVA es 4 (ultraprocesado). '
      'No se vuelven a penalizar azúcar, sal o grasas: Nutri-Score ya los considera. '
      'La escala orienta la comparación entre alimentos similares; no es una calificación oficial de Open Food Facts.';

  int? scoreFor(Product product) {
    final base = const {
      'a': 10,
      'b': 8,
      'c': 6,
      'd': 4,
      'e': 2,
    }[product.nutriScore];
    if (base == null) return null;
    return (base - (product.nova == 4 ? 1 : 0)).clamp(1, 10);
  }

  Recommendation evaluate(Product product) {
    final score = scoreFor(product);
    final observations = <String>[];
    if (product.hasScore) {
      observations.add(
        'Nutri-Score ${product.nutriScore.toUpperCase()}: compara el perfil nutricional con productos de la misma categoría.',
      );
    }
    if (product.nova != null) {
      observations.add(switch (product.nova) {
        1 => 'NOVA 1: alimento sin procesar o mínimamente procesado.',
        2 => 'NOVA 2: ingrediente culinario procesado.',
        3 => 'NOVA 3: alimento procesado.',
        4 =>
          'NOVA 4: producto ultraprocesado; considera alternativas menos procesadas.',
        _ => 'El grupo NOVA informado no es válido.',
      });
    }
    if (product.hasScore && !product.hasNova) {
      observations.add(
        'NOVA no está disponible. La nota es parcial: usa solo Nutri-Score, sin ajuste por procesamiento.',
      );
    }
    if (!product.hasScore) {
      observations.add(
        'Sin Nutri-Score no se asigna una nota del 1 al 10. Los datos ausentes no se cuentan como cero.',
      );
    }
    final sugar = product.nutrients['sugars_100g'];
    final salt = product.nutrients['salt_100g'];
    if (sugar != null) {
      observations.add(
        'Azúcares: ${_number(sugar)} g por 100 g o 100 ml, según la etiqueta.',
      );
    }
    if (salt != null) {
      observations.add(
        'Sal: ${_number(salt)} g por 100 g o 100 ml, según la etiqueta.',
      );
    }
    if (product.allergens.isNotEmpty) {
      observations.add(
        'Alérgenos declarados: ${product.allergens.join(', ')}. Comprueba la etiqueta física.',
      );
    }
    if (product.ingredients.isEmpty) {
      observations.add(
        'Faltan ingredientes; la evaluación tiene información limitada.',
      );
    }

    final favorable = ['a', 'b'].contains(product.nutriScore);
    final lessFavorable = ['d', 'e'].contains(product.nutriScore);
    return Recommendation(
      !product.hasScore
          ? 'Conoce antes de elegir'
          : favorable
          ? 'Una opción para considerar'
          : lessFavorable
          ? 'Compara tus alternativas'
          : 'El equilibrio está en la elección',
      !product.hasScore
          ? 'Todavía no hay suficiente información para valorar el perfil nutricional. Revisa ingredientes, porción y etiqueta.'
          : favorable
          ? 'Su Nutri-Score indica un perfil nutricional más favorable dentro de su categoría. Considera también la porción, los ingredientes y tus necesidades.'
          : lessFavorable
          ? 'Su Nutri-Score indica un perfil nutricional menos favorable. Compara con alimentos similares y considera la frecuencia de consumo.'
          : 'Tiene un perfil nutricional intermedio según Nutri-Score. La porción y el conjunto de tu alimentación también cuentan.',
      observations,
      score: score,
    );
  }

  String _number(double n) => n.toStringAsFixed(1).replaceAll('.0', '');
}

class AlternativeSearchResult {
  const AlternativeSearchResult({this.categoryTag, this.products = const []});
  final String? categoryTag;
  final List<Product> products;
}

/// Pure selection policy, independent of HTTP and widgets.
class AlternativeSelector {
  const AlternativeSelector();

  List<Product> select(
    Product original,
    Iterable<Product> candidates, {
    required String categoryTag,
    int limit = 3,
  }) {
    const evaluator = NutritionEvaluator();
    final originalScore = evaluator.scoreFor(original);
    if (originalScore == null || originalScore > 5 || limit <= 0) return [];
    final unique = <String, Product>{};
    for (final candidate in candidates) {
      final score = evaluator.scoreFor(candidate);
      if (candidate.barcode.isEmpty ||
          candidate.barcode == original.barcode ||
          !candidate.categoryTags.contains(categoryTag) ||
          score == null ||
          score < 6 ||
          score <= originalScore) {
        continue;
      }
      // Missing processing data must not create an artificial improvement.
      if (original.hasNova && !candidate.hasNova) continue;
      if (candidate.nutriScore.compareTo(original.nutriScore) > 0) continue;
      unique.putIfAbsent(candidate.barcode, () => candidate);
    }
    final ranked = unique.values.toList()
      ..sort((a, b) {
        final byScore = evaluator
            .scoreFor(b)!
            .compareTo(evaluator.scoreFor(a)!);
        if (byScore != 0) return byScore;
        final byNova = (a.nova ?? 5).compareTo(b.nova ?? 5);
        return byNova != 0 ? byNova : a.barcode.compareTo(b.barcode);
      });
    return ranked.take(limit).toList();
  }
}

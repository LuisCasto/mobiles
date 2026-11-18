import 'package:flutter/material.dart';
import '../../domain/product.dart';
import '../../domain/recommendation.dart';
import '../theme.dart';
import 'common.dart';

class RecommendationBadge extends StatelessWidget {
  const RecommendationBadge({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final score = const NutritionEvaluator().scoreFor(product);
    if (score == null) return const SizedBox.shrink();
    final color = AppColors.recommendation(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'uBuy $score/10',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RecommendationRating extends StatelessWidget {
  const RecommendationRating({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final recommendation = const NutritionEvaluator().evaluate(product);
    final score = recommendation.score;
    final color = AppColors.recommendation(score);
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: score == null
                    ? 'Recomendación uBuy sin puntuación'
                    : 'Recomendación uBuy: $score de 10',
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            value: score == null ? 0 : score / 10,
                            strokeWidth: 7,
                            color: color,
                            backgroundColor: color.withValues(alpha: .12),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              score == null ? '—' : '$score',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: color,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'de 10',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOMENDACIÓN UBUY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: AppColors.secondary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      recommendation.ratingLabel,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      score == null
                          ? 'Falta Nutri-Score para calcular una nota.'
                          : recommendation.suggestsAlternatives
                          ? 'Conviene comparar opciones antes de comprar y consumir.'
                          : 'Una referencia para comparar tu próxima compra.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.secondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (score != null) ...[
            Row(
              children: [
                for (var i = 1; i <= 10; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 10 ? 0 : 4),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= score
                              ? color
                              : color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '1 · Menos recomendable',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '10 · Más favorable',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Nutri-Score ${product.nutriScore.toUpperCase()}${product.nova == 4
                  ? ' · −1 punto por NOVA 4'
                  : product.hasNova
                  ? ' · NOVA ${product.nova}'
                  : ' · Nota parcial: NOVA no disponible'}',
              style: TextStyle(
                color: AppColors.secondary(context),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text(
              '¿Cómo se calcula?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            children: [
              Text(
                '${NutritionEvaluator.methodology}\n\nSin Nutri-Score no se asigna nota. '
                'Sin NOVA se muestra una puntuación parcial. Con 5 o menos se buscan alternativas mejor puntuadas.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.secondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

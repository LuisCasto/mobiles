import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../application/app_controller.dart';
import '../../domain/product.dart';
import '../../domain/recommendation.dart';
import '../theme.dart';
import 'common.dart';
import 'product_tile.dart';

class HealthierAlternatives extends StatefulWidget {
  const HealthierAlternatives({super.key, required this.product});
  final Product product;

  @override
  State<HealthierAlternatives> createState() => _HealthierAlternativesState();
}

class _HealthierAlternativesState extends State<HealthierAlternatives> {
  Future<AlternativeSearchResult>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).products.alternativesFor(widget.product);
  }

  @override
  void didUpdateWidget(covariant HealthierAlternatives oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _future = AppScope.of(context).products.alternativesFor(widget.product);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Alternativas con mejor perfil'),
      ContentCard(
        child: FutureBuilder<AlternativeSearchResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Row(
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Buscando opciones de la misma categoría…',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _future = AppScope.of(
                        context,
                      ).products.alternativesFor(widget.product);
                    }),
                    icon: const Icon(CupertinoIcons.refresh, size: 16),
                    label: const Text('Reintentar alternativas'),
                  ),
                ],
              );
            }
            final result = snapshot.data!;
            if (result.products.isEmpty) {
              return Text(
                result.categoryTag == null
                    ? 'No hay una categoría suficientemente específica para buscar alternativas comparables. Puedes probar con otros productos desde la búsqueda.'
                    : 'No encontramos opciones con mejor nota y datos suficientes en las categorías consultadas. Prueba a comparar otras marcas de este alimento.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary(context),
                  height: 1.7,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones de la misma categoría con al menos 6/10 y mejor nota que este producto.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary(context),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < result.products.length; i++) ...[
                  ProductTile(
                    product: result.products[i],
                    heroTag:
                        'alternative-${widget.product.barcode}-${result.products[i].barcode}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 14),
                    child: Text(
                      _reason(result.products[i]),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.green,
                        height: 1.6,
                      ),
                    ),
                  ),
                  if (i < result.products.length - 1) const Divider(height: 1),
                ],
                Text(
                  'La comparación usa la categoría y los indicadores de Open Food Facts. Revisa también ingredientes, porción y alérgenos al elegir.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondary(context),
                    height: 1.6,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  String _reason(Product alternative) {
    const evaluator = NutritionEvaluator();
    final improvement =
        evaluator.scoreFor(alternative)! - evaluator.scoreFor(widget.product)!;
    return '+$improvement ${improvement == 1 ? 'punto' : 'puntos'} en uBuy · '
        '${alternative.nutriScore != widget.product.nutriScore ? 'Mejor Nutri-Score' : 'Mismo Nutri-Score y menor procesamiento'}'
        '${alternative.hasNova ? ' · NOVA ${alternative.nova}' : ''}';
  }
}

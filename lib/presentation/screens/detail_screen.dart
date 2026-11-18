import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/app_controller.dart';
import '../../domain/product.dart';
import '../../domain/recommendation.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recommendation_rating.dart';
import '../widgets/healthier_alternatives.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.arguments});
  final ProductDetailArguments arguments;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _busy = false;
  Product get product => widget.arguments.product;

  Future<void> _save({bool favorite = false, bool shopping = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      await app.saveProduct(product, shopping: shopping);
      final entry = app.entryFor(product.barcode)!;
      if (favorite) {
        await app.updateEntry(entry.copyWith(favorite: !entry.favorite));
      }
      if (mounted) {
        showMessage(
          context,
          shopping
              ? 'Añadido a tu lista por comprar.'
              : favorite
              ? (entry.favorite
                    ? 'Quitado de favoritos.'
                    : 'Añadido a favoritos.')
              : 'Producto guardado en tu bitácora.',
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNote(SavedEntry entry) async {
    final text = TextEditingController(text: entry.note);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tu nota personal'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Algo que quieras recordar…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // The dialog's exit animation can still reference its controller.
    Future.delayed(const Duration(milliseconds: 400), text.dispose);
    if (note != null && mounted) {
      await runAction(
        context,
        () => AppScope.of(context).updateEntry(entry.copyWith(note: note)),
        success: 'Nota guardada.',
      );
    }
  }

  Future<void> _delete(SavedEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar de tu bitácora?'),
        content: const Text(
          'Se eliminarán esta entrada, su foto local y sus notas. El catálogo de Open Food Facts no se modifica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runAction(context, () async {
      await AppScope.of(context).removeEntry(entry);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final entry = app.entryFor(product.barcode);
    final recommendation = const NutritionEvaluator().evaluate(product);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del producto'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _save(favorite: true),
            tooltip: entry?.favorite == true
                ? 'Quitar de favoritos'
                : 'Añadir a favoritos',
            icon: Icon(
              entry?.favorite == true
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              color: entry?.favorite == true ? AppColors.red : null,
            ),
          ),
          if (entry != null)
            IconButton(
              onPressed: () => _delete(entry),
              tooltip: 'Eliminar entrada',
              icon: const Icon(CupertinoIcons.trash, size: 21),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 55),
            children: [
              ContentCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final image = ProductImage(
                      product: product,
                      size: constraints.maxWidth < 480 ? 120 : 165,
                      heroTag: widget.arguments.heroTag,
                    );
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand.isEmpty
                              ? 'DESCUBRE EL PRODUCTO'
                              : product.brand.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1.2,
                          ),
                        ),
                        if (product.quantity.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            product.quantity,
                            style: TextStyle(
                              color: AppColors.secondary(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ScorePill(product: product),
                            if (product.nova != null)
                              Chip(
                                label: Text(
                                  'NOVA ${product.nova}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.barcode,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary(context),
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    );
                    return constraints.maxWidth < 480
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: image),
                              const SizedBox(height: 24),
                              info,
                            ],
                          )
                        : Row(
                            children: [
                              image,
                              const SizedBox(width: 30),
                              Expanded(child: info),
                            ],
                          );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || entry != null ? null : () => _save(),
                    icon: Icon(
                      entry == null
                          ? CupertinoIcons.bookmark
                          : CupertinoIcons.checkmark_circle,
                      size: 18,
                    ),
                    label: Text(
                      entry == null
                          ? 'Guardar en mi bitácora'
                          : 'Guardado en tu bitácora',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || entry?.shopping == true
                        ? null
                        : () => _save(shopping: true),
                    icon: const Icon(CupertinoIcons.cart_badge_plus, size: 18),
                    label: Text(
                      entry?.shopping == true
                          ? 'En tu lista de compra'
                          : 'Añadir por comprar',
                    ),
                  ),
                ],
              ),
              const SectionLabel('¿Qué tan recomendable es?'),
              RecommendationRating(product: product),
              if (recommendation.suggestsAlternatives)
                HealthierAlternatives(product: product),
              const SectionLabel('Una lectura más clara'),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.leaf_arrow_circlepath,
                            color: AppColors.green,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Text(
                            'Lectura nutricional',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      recommendation.title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recommendation.summary,
                      style: TextStyle(
                        color: AppColors.secondary(context),
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                    if (recommendation.observations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      for (final observation in recommendation.observations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(
                                  CupertinoIcons.circle_fill,
                                  size: 5,
                                  color: AppColors.green,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  observation,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Resumen basado en los indicadores disponibles. No mide por sí solo la calidad total del alimento.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondary(context),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Ingredientes'),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.ingredients.isEmpty
                          ? 'Este producto aún no tiene ingredientes registrados.'
                          : product.ingredients,
                      style: TextStyle(
                        height: 1.8,
                        fontSize: 14,
                        color: product.ingredients.isEmpty
                            ? AppColors.secondary(context)
                            : null,
                      ),
                    ),
                    if (product.allergens.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Alérgenos declarados',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.allergens
                            .map(
                              (a) => Chip(
                                label: Text(
                                  a,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: const Icon(
                                  CupertinoIcons.exclamationmark_circle,
                                  size: 15,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionLabel('Información nutricional'),
              _nutritionTable(),
              if (entry != null) ...[
                SectionLabel(
                  'Tu nota personal',
                  trailing: TextButton(
                    onPressed: () => _editNote(entry),
                    child: const Text('Editar'),
                  ),
                ),
                ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.note.isEmpty
                            ? '¿Algo que quieras recordar? Añade una nota sobre este producto.'
                            : entry.note,
                        style: TextStyle(
                          height: 1.6,
                          color: entry.note.isEmpty
                              ? AppColors.secondary(context)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Guardado el ${friendlyDate(entry.createdAt)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.shopping)
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Ya lo compré',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: entry.purchased,
                    onChanged: (v) => runAction(
                      context,
                      () => app.updateEntry(entry.copyWith(purchased: v)),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              Text(
                product.source == ProductSource.openFoodFacts
                    ? 'Fuente: Open Food Facts · Base de datos ODbL · Imágenes CC BY-SA. La información es aportada por la comunidad; comprueba la etiqueta del envase.'
                    : 'Aportación de la comunidad uBuy. Los datos aún no han sido verificados por Open Food Facts.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: AppColors.secondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => runAction(context, () async {
                    final uri = Uri.https(
                      'world.openfoodfacts.org',
                      product.source == ProductSource.openFoodFacts
                          ? '/product/${product.barcode}'
                          : '/cgi/product.pl',
                      product.source == ProductSource.contribution
                          ? {'type': 'edit', 'code': product.barcode}
                          : null,
                    );
                    if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('No se pudo abrir Open Food Facts.');
                    }
                  }),
                  icon: const Icon(
                    CupertinoIcons.arrow_up_right_square,
                    size: 17,
                  ),
                  label: Text(
                    product.source == ProductSource.openFoodFacts
                        ? 'Ver en Open Food Facts'
                        : 'Contribuir también en Open Food Facts',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nutritionTable() {
    const labels = <String, (String, String)>{
      'energy-kcal_100g': ('Energía', 'kcal'),
      'fat_100g': ('Grasas', 'g'),
      'saturated-fat_100g': ('Grasas saturadas', 'g'),
      'carbohydrates_100g': ('Carbohidratos', 'g'),
      'sugars_100g': ('Azúcares', 'g'),
      'fiber_100g': ('Fibra', 'g'),
      'proteins_100g': ('Proteínas', 'g'),
      'salt_100g': ('Sal', 'g'),
    };
    final available = labels.keys.where(product.nutrients.containsKey).toList();
    if (available.isEmpty) {
      return const ContentCard(
        child: Text('No hay una tabla nutricional disponible.'),
      );
    }
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POR 100 G / 100 ML · SEGÚN LA ETIQUETA',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondary(context),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 15),
          for (var i = 0; i < available.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labels[available[i]]!.$1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${product.nutrients[available[i]]!.toStringAsFixed(1).replaceAll('.0', '')} ${labels[available[i]]!.$2}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (i < available.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

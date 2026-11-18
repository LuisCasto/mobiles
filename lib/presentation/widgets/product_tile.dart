import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/product.dart';
import '../navigation.dart';
import '../theme.dart';
import 'common.dart';
import 'recommendation_rating.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.heroTag,
    this.entry,
    this.onCheck,
  });
  final Product product;
  final String heroTag;
  final SavedEntry? entry;
  final VoidCallback? onCheck;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: ProductDetailArguments(product, heroTag: heroTag),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        child: Row(
          children: [
            if (onCheck != null) ...[
              IconButton(
                onPressed: onCheck,
                tooltip: entry?.purchased == true
                    ? 'Marcar como pendiente'
                    : 'Marcar como comprado',
                icon: Icon(
                  entry?.purchased == true
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: entry?.purchased == true
                      ? AppColors.blue
                      : AppColors.secondary(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),
            ],
            ProductImage(product: product, size: 58, heroTag: heroTag),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: entry?.purchased == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      product.brand,
                      product.quantity,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ScorePill(product: product),
                      RecommendationBadge(product: product),
                      if (product.source == ProductSource.contribution)
                        Text(
                          'Tu aportación',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.purple,
                          ),
                        ),
                      if (entry?.favorite == true)
                        const Icon(
                          CupertinoIcons.heart_fill,
                          size: 13,
                          color: AppColors.red,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.secondary(context),
            ),
          ],
        ),
      ),
    ),
  );
}

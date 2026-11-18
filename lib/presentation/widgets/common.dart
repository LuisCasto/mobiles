import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/product.dart';
import '../theme.dart';
import '../navigation.dart';

Future<void> scanAndOpen(BuildContext context) async {
  final code = await Navigator.pushNamed(context, AppRoutes.scanner);
  if (code is String && context.mounted) {
    await Navigator.pushNamed(context, AppRoutes.lookup, arguments: code);
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showMessage(context, success);
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString());
  }
}

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.size = 64,
    this.heroTag,
  });
  final Product product;
  final double size;
  final Object? heroTag;
  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      CupertinoIcons.cube_box,
      color: AppColors.secondary(context),
      size: size * .38,
    );
    Widget image = placeholder;
    if (product.photoBase64.isNotEmpty) {
      try {
        image = Image.memory(
          base64Decode(product.photoBase64),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => placeholder,
        );
      } catch (_) {
        image = placeholder;
      }
    } else if (product.imageUrl.startsWith('https://')) {
      image = Image.network(
        product.imageUrl,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final frame = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: image,
    );
    return heroTag == null ? frame : Hero(tag: heroTag!, child: frame);
  }
}

class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final color = AppColors.score(product.nutriScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        product.hasScore
            ? 'Nutri-Score ${product.nutriScore.toUpperCase()}'
            : 'Sin evaluar',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondary(context),
                height: 1.6,
                fontSize: 14,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14, top: 28),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

String friendlyDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

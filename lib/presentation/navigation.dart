import '../domain/product.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const search = '/search';
  static const detail = '/product';
  static const lookup = '/lookup';
  static const scanner = '/scan';
  static const create = '/new';
  static const account = '/account';
  static const about = '/about';
}

class ProductDetailArguments {
  const ProductDetailArguments(this.product, {this.heroTag});
  final Product product;
  final Object? heroTag;
}

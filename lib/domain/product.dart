enum ProductSource { openFoodFacts, contribution }

/// Domain objects do not depend on widgets, plugins or HTTP clients.
class Product {
  const Product({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.quantity = '',
    this.imageUrl = '',
    this.photoBase64 = '',
    this.ingredients = '',
    this.nutriScore = '',
    this.nova,
    this.nutrients = const {},
    this.allergens = const [],
    this.categoryTags = const [],
    this.source = ProductSource.openFoodFacts,
  });

  final String barcode;
  final String name;
  final String brand;
  final String quantity;
  final String imageUrl;
  // Durable image contents, not a temporary blob URL (important on the web).
  final String photoBase64;
  final String ingredients;
  final String nutriScore;
  final int? nova;
  final Map<String, double> nutrients;
  final List<String> allergens;

  /// Canonical taxonomy tags, ordered by OFF from general to specific.
  final List<String> categoryTags;
  final ProductSource source;

  bool get hasScore => const ['a', 'b', 'c', 'd', 'e'].contains(nutriScore);
  bool get hasNova => nova != null && nova! >= 1 && nova! <= 4;

  /// Avoid comparing all foods/beverages or using brand-specific free-text tags.
  /// English canonical taxonomy tags are shared by OFF's translated categories.
  List<String> get comparisonCategories => categoryTags.reversed
      .where(
        (tag) =>
            RegExp(r'^en:[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(tag) &&
            !const {
              'en:foods',
              'en:beverages',
              'en:plant-based-foods-and-beverages',
              'en:plant-based-foods',
              'en:breakfasts',
              'en:snacks',
              'en:sweet-snacks',
              'en:dairies',
              'en:meats',
              'en:groceries',
              'en:desserts',
              'en:fruits-and-vegetables-based-foods',
            }.contains(tag),
      )
      .toSet()
      .take(2)
      .toList();

  factory Product.fromOff(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString().trim();
    final rawNutrients = json['nutriments'];
    final nutrients = <String, double>{};
    if (rawNutrients is Map) {
      for (final entry in rawNutrients.entries) {
        final value = double.tryParse(entry.value.toString());
        if (value != null && value.isFinite) {
          nutrients[entry.key.toString()] = value;
        }
      }
    }
    return Product(
      barcode: text('code'),
      name: text('product_name_es').isNotEmpty
          ? text('product_name_es')
          : text('product_name').isNotEmpty
          ? text('product_name')
          : 'Producto sin nombre',
      brand: text('brands'),
      quantity: text('quantity'),
      imageUrl: text('image_front_url').isNotEmpty
          ? text('image_front_url')
          : text('image_url'),
      ingredients: text('ingredients_text_es').isNotEmpty
          ? text('ingredients_text_es')
          : text('ingredients_text'),
      nutriScore: text('nutriscore_grade').toLowerCase(),
      nova: int.tryParse(text('nova_group')),
      nutrients: nutrients,
      categoryTags: List<String>.from(
        (json['categories_hierarchy'] as List?)?.isNotEmpty == true
            ? json['categories_hierarchy'] as List
            : json['categories_tags'] as List? ?? [],
      ),
      allergens: (json['allergens_tags'] as List? ?? [])
          .map(
            (e) => e
                .toString()
                .replaceFirst(RegExp(r'^\w\w:'), '')
                .replaceAll('-', ' '),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'brand': brand,
    'quantity': quantity,
    'imageUrl': imageUrl,
    'photoBase64': photoBase64,
    'ingredients': ingredients,
    'nutriScore': nutriScore,
    'nova': nova,
    'nutrients': nutrients,
    'allergens': allergens,
    'categoryTags': categoryTags,
    'source': source.name,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    barcode: json['barcode'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String? ?? '',
    quantity: json['quantity'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    photoBase64: json['photoBase64'] as String? ?? '',
    ingredients: json['ingredients'] as String? ?? '',
    nutriScore: json['nutriScore'] as String? ?? '',
    nova: json['nova'] as int?,
    nutrients: (json['nutrients'] as Map? ?? {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    ),
    allergens: List<String>.from(json['allergens'] as List? ?? []),
    categoryTags: List<String>.from(json['categoryTags'] as List? ?? []),
    source: json['source'] == 'contribution'
        ? ProductSource.contribution
        : ProductSource.openFoodFacts,
  );
}

class SavedEntry {
  const SavedEntry({
    required this.id,
    required this.product,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.favorite = false,
    this.purchased = false,
    this.shopping = false,
    this.shared = false,
  });

  final String id;
  final Product product;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final bool favorite;
  final bool purchased;
  final bool shopping;
  final bool shared;

  SavedEntry copyWith({
    String? note,
    bool? favorite,
    bool? purchased,
    bool? shopping,
  }) => SavedEntry(
    id: id,
    product: product,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    note: note ?? this.note,
    favorite: favorite ?? this.favorite,
    purchased: purchased ?? this.purchased,
    shopping: shopping ?? this.shopping,
    shared: shared,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'product': product.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'note': note,
    'favorite': favorite,
    'purchased': purchased,
    'shopping': shopping,
    'shared': shared,
  };

  factory SavedEntry.fromJson(Map<String, dynamic> json) => SavedEntry(
    id: json['id'] as String,
    product: Product.fromJson(
      Map<String, dynamic>.from(json['product'] as Map),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    note: json['note'] as String? ?? '',
    favorite: json['favorite'] == true,
    purchased: json['purchased'] == true,
    shopping: json['shopping'] == true,
    shared: json['shared'] == true,
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });
  final String id;
  final String name;
  final String email;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

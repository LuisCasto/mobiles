import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/product.dart';

class CloudRepository {
  CloudRepository(this.client);
  final SupabaseClient client;

  Future<List<SavedEntry>> load(String owner) async {
    final rows = await client
        .from('entries')
        .select('data')
        .eq('user_id', owner);
    return rows
        .map(
          (row) => SavedEntry.fromJson(
            Map<String, dynamic>.from(row['data'] as Map),
          ),
        )
        .toList();
  }

  Future<void> save(String owner, SavedEntry entry) async {
    await client.from('entries').upsert({
      'id': entry.id,
      'user_id': owner,
      'data': entry.toJson(),
    });
  }

  Future<void> publish(String owner, SavedEntry entry) async {
    await client.from('contributions').upsert({
      'id': entry.id,
      'user_id': owner,
      'name': entry.product.name,
      'barcode': entry.product.barcode,
      'product': entry.product.toJson(),
    });
  }

  Future<void> delete(String owner, String id) async {
    await client
        .from('contributions')
        .delete()
        .eq('id', id)
        .eq('user_id', owner);
    await client.from('entries').delete().eq('id', id).eq('user_id', owner);
  }

  Future<List<Product>> search(String query) async {
    // Escape SQL pattern wildcards so user text remains literal.
    final pattern = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await client
        .from('contributions')
        .select('product')
        .ilike('name', '%$pattern%')
        .limit(20);
    return rows
        .map(
          (r) =>
              Product.fromJson(Map<String, dynamic>.from(r['product'] as Map)),
        )
        .toList();
  }
}

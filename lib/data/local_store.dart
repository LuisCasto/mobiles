import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/product.dart';

class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class EntryRepository {
  Future<List<SavedEntry>> load(String owner);
  Future<void> save(String owner, List<SavedEntry> entries);
}

class LocalEntryRepository implements EntryRepository {
  LocalEntryRepository(this.preferences);
  final SharedPreferences preferences;

  @override
  Future<List<SavedEntry>> load(String owner) async {
    try {
      final raw = preferences.getString('ubuy.entries.$owner');
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => SavedEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      throw const AppException(
        'No se pudo leer tu bitácora. Tus datos no se han sobrescrito. Intenta recargar.',
      );
    }
  }

  @override
  Future<void> save(String owner, List<SavedEntry> entries) async {
    try {
      final ok = await preferences.setString(
        'ubuy.entries.$owner',
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
      if (!ok) throw StateError('storage rejected write');
    } catch (_) {
      throw const AppException(
        'No se pudo guardar. El almacenamiento puede estar lleno; prueba con una fotografía más pequeña.',
      );
    }
  }
}

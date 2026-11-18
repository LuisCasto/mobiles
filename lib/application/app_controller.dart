import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/auth_repository.dart';
import '../data/cloud_repository.dart';
import '../data/local_store.dart';
import '../data/open_food_facts_repository.dart';
import '../domain/product.dart';

enum CollectionKind { all, shopping, favorites, contributions }

class AppController extends ChangeNotifier {
  AppController({
    required this.entriesRepository,
    required this.products,
    required this.auth,
    required this.preferences,
    this.cloud,
  });

  final EntryRepository entriesRepository;
  final ProductRepository products;
  final AuthRepository auth;
  final SharedPreferences preferences;
  final CloudRepository? cloud;
  UserProfile? user;
  List<SavedEntry> _entries = [];
  List<SavedEntry> get entries => List.unmodifiable(_entries);
  String get owner => user?.id ?? 'guest';
  bool get canSync => cloud != null && user != null;
  String? storageError;
  bool syncing = false;
  ThemeMode themeMode = ThemeMode.system;
  Future<void> _writes = Future.value();

  Future<void> initialize() async {
    user = await auth.restore();
    final theme = preferences.getString('ubuy.theme');
    themeMode = ThemeMode.values.firstWhere(
      (t) => t.name == theme,
      orElse: () => ThemeMode.system,
    );
    await reload();
  }

  Future<void> reload() async {
    try {
      _entries = await entriesRepository.load(owner);
      _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      storageError = null;
    } catch (e) {
      storageError = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  SavedEntry? entryFor(String barcode) {
    for (final entry in _entries) {
      if (entry.product.barcode == barcode) return entry;
    }
    return null;
  }

  List<SavedEntry> collection(CollectionKind kind) => _entries
      .where(
        (entry) => switch (kind) {
          CollectionKind.all => true,
          CollectionKind.shopping => entry.shopping,
          CollectionKind.favorites => entry.favorite,
          CollectionKind.contributions =>
            entry.product.source == ProductSource.contribution,
        },
      )
      .toList();

  /// Serializes read-modify-write operations to avoid lost rapid toggles.
  Future<void> _mutate(List<SavedEntry> Function() change) {
    final operation = _writes.then((_) async {
      if (storageError != null) throw AppException(storageError!);
      final updated = change();
      await entriesRepository.save(owner, updated);
      _entries = updated;
      notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> saveProduct(
    Product product, {
    String note = '',
    bool shopping = false,
    bool shared = false,
  }) => _mutate(() {
    final existing = entryFor(product.barcode);
    if (existing != null) {
      return _entries
          .map(
            (e) => e.id == existing.id
                ? e.copyWith(
                    note: note.isEmpty ? e.note : note,
                    shopping: shopping || e.shopping,
                  )
                : e,
          )
          .toList();
    }
    final now = DateTime.now();
    return [
      SavedEntry(
        id: const Uuid().v4(),
        product: product,
        createdAt: now,
        updatedAt: now,
        note: note.trim(),
        shopping: shopping,
        shared: shared,
      ),
      ..._entries,
    ];
  });

  Future<void> updateEntry(SavedEntry entry) =>
      _mutate(() => _entries.map((e) => e.id == entry.id ? entry : e).toList());

  Future<void> removeEntry(SavedEntry entry) async {
    if (canSync) await cloud!.delete(owner, entry.id);
    await _mutate(() => _entries.where((e) => e.id != entry.id).toList());
  }

  Future<void> authenticate({
    required bool register,
    required String name,
    required String email,
    required String password,
  }) async {
    await _writes;
    final profile = register
        ? await auth.register(name, email, password)
        : await auth.signIn(email, password);
    if (profile == null) {
      throw const AppException(
        'Cuenta creada. Revisa tu correo para confirmarla y después inicia sesión.',
      );
    }
    user = profile;
    _entries = [];
    await reload();
  }

  Future<void> signOut() async {
    await _writes;
    await auth.signOut();
    user = null;
    _entries = [];
    await reload();
  }

  Future<void> sync() async {
    if (!canSync || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      await _writes;
      final remote = await cloud!.load(owner);
      await _mutate(() {
        final merged = {for (final e in remote) e.id: e};
        for (final e in _entries) {
          if (!merged.containsKey(e.id) ||
              !merged[e.id]!.updatedAt.isAfter(e.updatedAt)) {
            merged[e.id] = e;
          }
        }
        return merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      for (final entry in _entries) {
        await cloud!.save(owner, entry);
        if (entry.shared) await cloud!.publish(owner, entry);
      }
    } catch (_) {
      throw const AppException(
        'No se pudo sincronizar. Tus cambios siguen guardados en este dispositivo; vuelve a intentarlo.',
      );
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    await preferences.setString('ubuy.theme', mode.name);
    themeMode = mode;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

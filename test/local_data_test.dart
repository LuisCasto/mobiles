import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubuy/application/app_controller.dart';
import 'package:ubuy/data/auth_repository.dart';
import 'package:ubuy/data/local_store.dart';
import 'package:ubuy/data/open_food_facts_repository.dart';
import 'package:ubuy/domain/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'La foto y los metadatos sobreviven a una nueva lectura del almacén',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final image = base64Encode([137, 80, 78, 71]);
      final now = DateTime(2026, 11, 16);
      final entry = SavedEntry(
        id: 'entry-1',
        product: Product(
          barcode: '7501234567890',
          name: 'Avena',
          photoBase64: image,
          source: ProductSource.contribution,
        ),
        createdAt: now,
        updatedAt: now,
        note: 'Mi nota',
        favorite: true,
        shopping: true,
      );
      await LocalEntryRepository(preferences).save('user-1', [entry]);
      final reloaded = await LocalEntryRepository(preferences).load('user-1');
      expect(reloaded.single.product.photoBase64, image);
      expect(reloaded.single.note, 'Mi nota');
      expect(reloaded.single.favorite, isTrue);
      expect(reloaded.single.shopping, isTrue);
      expect(
        await LocalEntryRepository(preferences).load('other-user'),
        isEmpty,
      );
      await LocalEntryRepository(
        preferences,
      ).save('other-user', [entry.copyWith(note: 'Otra persona')]);
      expect(
        (await LocalEntryRepository(
          preferences,
        ).load('other-user')).single.product.barcode,
        reloaded.single.product.barcode,
      );
      expect(
        (await LocalEntryRepository(preferences).load('user-1')).single.note,
        'Mi nota',
      );
    },
  );

  test(
    'Las escrituras simultáneas no pierden productos ni duplican códigos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final products = OpenFoodFactsRepository();
      addTearDown(products.dispose);
      final app = AppController(
        entriesRepository: LocalEntryRepository(preferences),
        products: products,
        auth: LocalAuthRepository(preferences),
        preferences: preferences,
      );
      addTearDown(app.dispose);
      await app.initialize();
      const first = Product(barcode: '7501234567890', name: 'Primero');
      const second = Product(barcode: '7501234567891', name: 'Segundo');
      await Future.wait([
        app.saveProduct(first),
        app.saveProduct(second),
        app.saveProduct(first, shopping: true),
      ]);
      await app.reload();
      expect(app.entries, hasLength(2));
      expect(app.entryFor(first.barcode)!.shopping, isTrue);
    },
  );

  test('Un almacén dañado se informa sin sobrescribir los datos', () async {
    const damaged = '{invalid json';
    SharedPreferences.setMockInitialValues({'ubuy.entries.guest': damaged});
    final preferences = await SharedPreferences.getInstance();
    await expectLater(
      LocalEntryRepository(preferences).load('guest'),
      throwsA(isA<AppException>()),
    );
    expect(preferences.getString('ubuy.entries.guest'), damaged);
  });

  test(
    'La cuenta local restaura sesión y verifica contraseñas sin almacenarlas en claro',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final auth = LocalAuthRepository(preferences);
      const password = 'UnaClaveDePrueba123';
      final user = await auth.register('Axel', 'Axel@Example.com', password);
      expect(user.email, 'axel@example.com');
      expect((await LocalAuthRepository(preferences).restore())!.id, user.id);
      expect(preferences.getString('ubuy.accounts'), isNot(contains(password)));
      await auth.signOut();
      expect(await auth.restore(), isNull);
      await expectLater(
        auth.signIn(user.email, 'incorrecta'),
        throwsA(isA<AppException>()),
      );
      expect((await auth.signIn(user.email, password)).id, user.id);
    },
  );
}

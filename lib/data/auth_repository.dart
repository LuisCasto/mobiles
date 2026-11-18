import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/product.dart';
import 'local_store.dart';

abstract interface class AuthRepository {
  bool get isCloud;
  Future<UserProfile?> restore();
  Future<UserProfile?> register(String name, String email, String password);
  Future<UserProfile> signIn(String email, String password);
  Future<void> signOut();
}

/// Device-only accounts for a runnable classroom build without a backend.
/// Passwords are salted and stretched; this is not server authentication.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.preferences);
  final SharedPreferences preferences;
  static const _accountsKey = 'ubuy.accounts';
  static const _sessionKey = 'ubuy.session';
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  @override
  bool get isCloud => false;

  List<Map<String, dynamic>> _accounts() =>
      (jsonDecode(preferences.getString(_accountsKey) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<String> _derive(String password, List<int> salt) async {
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  @override
  Future<UserProfile?> restore() async {
    final id = preferences.getString(_sessionKey);
    for (final account in _accounts()) {
      if (account['id'] == id) return UserProfile.fromJson(account);
    }
    return null;
  }

  @override
  Future<UserProfile> register(
    String name,
    String email,
    String password,
  ) async {
    final accounts = _accounts();
    final normalized = email.trim().toLowerCase();
    if (accounts.any((a) => a['email'] == normalized)) {
      throw const AppException(
        'Ya existe una cuenta con este correo en este dispositivo.',
      );
    }
    final profile = UserProfile(
      id: const Uuid().v4(),
      name: name.trim(),
      email: normalized,
    );
    final salt = SecretKeyData.random(length: 16).bytes;
    accounts.add({
      ...profile.toJson(),
      'salt': base64Encode(salt),
      'hash': await _derive(password, salt),
    });
    if (!await preferences.setString(_accountsKey, jsonEncode(accounts))) {
      throw const AppException(
        'No se pudo crear la cuenta en este dispositivo.',
      );
    }
    await preferences.setString(_sessionKey, profile.id);
    return profile;
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    for (final account in _accounts()) {
      if (account['email'] != email.trim().toLowerCase()) continue;
      final derived = await _derive(
        password,
        base64Decode(account['salt'] as String),
      );
      final expected = base64Decode(account['hash'] as String);
      final actual = base64Decode(derived);
      var difference = actual.length ^ expected.length;
      for (var i = 0; i < actual.length && i < expected.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      if (difference == 0) {
        await preferences.setString(_sessionKey, account['id'] as String);
        return UserProfile.fromJson(account);
      }
    }
    throw const AppException('Correo o contraseña incorrectos.');
  }

  @override
  Future<void> signOut() async => preferences.remove(_sessionKey);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);
  final SupabaseClient client;
  @override
  bool get isCloud => true;
  UserProfile _profile(User user) => UserProfile(
    id: user.id,
    name: user.userMetadata?['name'] as String? ?? 'Mi cuenta',
    email: user.email ?? '',
  );
  @override
  Future<UserProfile?> restore() async => client.auth.currentUser == null
      ? null
      : _profile(client.auth.currentUser!);
  @override
  Future<UserProfile?> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
    );
    return response.session == null ? null : _profile(response.user!);
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _profile(response.user!);
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

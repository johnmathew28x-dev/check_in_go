import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps Supabase sessions and PKCE values in the platform secure store.
class SecureSupabaseStorage extends LocalStorage implements GotrueAsyncStorage {
  SecureSupabaseStorage({
    required String legacySessionKey,
    FlutterSecureStorage? storage,
  })  : _legacySessionKey = legacySessionKey,
        _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'checkingo.supabase.session';
  final String _legacySessionKey;
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {
    // Migrate existing Supabase sessions out of SharedPreferences once.
    final preferences = await SharedPreferences.getInstance();
    final legacySession = preferences.getString(_legacySessionKey);
    if (legacySession == null) return;

    if (await _storage.read(key: _sessionKey) == null) {
      await _storage.write(key: _sessionKey, value: legacySession);
    }
    await preferences.remove(_legacySessionKey);
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: 'checkingo.supabase.pkce.$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: 'checkingo.supabase.pkce.$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: 'checkingo.supabase.pkce.$key');
}

// lib/core/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final SharedPreferences _preferences; // <-- use late final

  // Initialize SharedPreferences
  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // Secure Storage Methods
  Future<void> writeSecure(String key, dynamic value) async {
    await _secureStorage.write(key: key, value: value.toString());
  }

  Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Shared Preferences Methods
  Future<void> write(String key, dynamic value) async {
    await _preferences.setString(key, value.toString());
  }

  String? read(String key) {
    return _preferences.getString(key);
  }

  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _preferences.clear();
  }
}

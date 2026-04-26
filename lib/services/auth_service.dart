import 'package:shared_preferences/shared_preferences.dart';
import 'package:halaph/repositories/backend_repository.dart';
import 'package:halaph/models/user.dart';

class AuthService {
  static const _emailKey = 'auth_user_email';
  static const _nameKey = 'auth_user_name';
  static const _tokenKey = 'auth_token';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<User?> getCurrentUser() async {
    final repo = BackendRepository();
    final user = await repo.getCurrentUser();
    if (user != null) return user;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    final name = prefs.getString(_nameKey);
    if (email != null && name != null) {
      return User(email: email, name: name);
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final repo = BackendRepository();
    final user = await repo.getCurrentUser();
    if (user != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null;
  }

  Future<User?> login(String email, String password) async {
    if (email.isNotEmpty && password.isNotEmpty) {
      final repo = BackendRepository();
      final user = await repo.login(email, password);
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_emailKey, user.email);
        await prefs.setString(_nameKey, user.name);
        await prefs.setString(_tokenKey, 'mock-token');
        return user;
      }
    }
    return null;
  }

  Future<User?> register(String email, String password, {String? name}) async {
    final repo = BackendRepository();
    final user = await repo.register(email, password);
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailKey, user.email);
      await prefs.setString(_nameKey, name ?? user.name);
      await prefs.setString(_tokenKey, 'mock-token');
      return User(email: user.email, name: name ?? user.name);
    }
    return null;
  }

  Future<String> getCurrentUserIdentifier() async {
    final user = await getCurrentUser();
    if (user != null && user.email.isNotEmpty) return user.email;
    return 'current_user';
  }

  Future<void> logout() async {
    final repo = BackendRepository();
    await repo.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_tokenKey);
  }
}

import 'dart:async';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/user.dart';

// User model is defined in lib/models/user.dart

// Simple scratch backend: in-memory and resettable per app run
class BackendApi {
  static final BackendApi _instance = BackendApi._internal();
  factory BackendApi() => _instance;
  BackendApi._internal();

  String? _currentToken;
  final Map<String, User> _tokensToUsers = {};
  final Map<String, TravelPlan> _plansById = {};

  Future<User?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final user = User(email: email, name: email.split('@').first);
    _currentToken = 'token_$email';
    _tokensToUsers[_currentToken!] = user;
    return user;
  }

  Future<User?> register(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return login(email, password);
  }

  Future<User?> getCurrentUser() async {
    if (_currentToken == null) return null;
    return _tokensToUsers[_currentToken!];
  }

  Future<void> logout() async {
    _currentToken = null;
  }

  Future<List<TravelPlan>> getUserPlans() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _plansById.values.toList();
  }

  Future<TravelPlan> savePlan(TravelPlan plan) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _plansById[plan.id] = plan;
    return plan;
  }

  Future<TravelPlan?> getPlanById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _plansById[id];
  }

  Future<String> sharePlan(String planId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'https://halaph.app/plan?planId=$planId';
  }
}

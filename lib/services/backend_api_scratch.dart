import 'dart:async';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/user.dart';
import 'backend_api_interface.dart';

class ScratchBackendApi implements BackendApiInterface {
  String? _token;
  final Map<String, User> _users = {};
  final Map<String, TravelPlan> _plans = {};
  static final ScratchBackendApi _instance = ScratchBackendApi._internal();
  factory ScratchBackendApi() => _instance;
  ScratchBackendApi._internal();

  @override
  Future<User?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final user = User(email: email, name: email.split('@').first);
    _token = 'scratch-token-$email';
    _users[_token!] = user;
    return user;
  }

  @override
  Future<User?> register(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return login(email, password);
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_token == null) return null;
    return _users[_token!];
  }

  @override
  Future<List<TravelPlan>> getUserPlans() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _plans.values.toList();
  }

  @override
  Future<TravelPlan> savePlan(TravelPlan plan) async {
    await Future.delayed(const Duration(milliseconds: 120));
    _plans[plan.id] = plan;
    return plan;
  }

  @override
  Future<TravelPlan?> getPlanById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _plans[id];
  }

  @override
  Future<String> sharePlan(String planId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'https://halaph.app/plan?planId=$planId';
  }
}

// User model moved to lib/models/user.dart

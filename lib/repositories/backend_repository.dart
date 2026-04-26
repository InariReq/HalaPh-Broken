import 'package:halaph/models/plan.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/services/backend_api_interface.dart';
import 'package:halaph/services/backend_api_http.dart';
import 'package:halaph/services/backend_api_scratch.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendRepository {
  late final BackendApiInterface _api;
  static final BackendRepository _instance = BackendRepository._internal();
  factory BackendRepository() => _instance;
  BackendRepository._internal() {
    String? apiBase;
    try {
      apiBase = dotenv.env['API_BASE_URL'];
    } catch (_) {
      apiBase = null;
    }
    if (apiBase != null && apiBase.isNotEmpty) {
      _api = HttpBackendApi(apiBase);
    } else {
      _api = ScratchBackendApi();
    }
  }

  Future<User?> login(String email, String password) =>
      _api.login(email, password);
  Future<User?> register(String email, String password) =>
      _api.register(email, password);
  Future<void> logout() => _api.logout();
  Future<User?> getCurrentUser() => _api.getCurrentUser();

  Future<List<TravelPlan>> getUserPlans() => _api.getUserPlans();
  Future<TravelPlan> savePlan(TravelPlan plan) => _api.savePlan(plan);
  Future<TravelPlan?> getPlanById(String id) => _api.getPlanById(id);
  Future<String> sharePlan(String planId) => _api.sharePlan(planId);
}

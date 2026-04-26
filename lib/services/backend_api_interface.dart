import 'package:halaph/models/plan.dart';
import 'package:halaph/models/user.dart';

abstract class BackendApiInterface {
  Future<User?> login(String email, String password);
  Future<User?> register(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<List<TravelPlan>> getUserPlans();
  Future<TravelPlan> savePlan(TravelPlan plan);
  Future<TravelPlan?> getPlanById(String id);
  Future<String> sharePlan(String planId);
}
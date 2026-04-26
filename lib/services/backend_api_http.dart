import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/user.dart';
import 'backend_api_interface.dart';

class HttpBackendApi implements BackendApiInterface {
  String? _token;
  final String _baseUrl;
  HttpBackendApi(this._baseUrl);

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  @override
  Future<User?> login(String email, String password) async {
    final resp = await http.post(Uri.parse('$_baseUrl/login'), headers: _headers(), body: json.encode({'email': email, 'password': password}));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      _token = data['token'];
      final user = User(email: data['user']['email'], name: data['user']['name']);
      return user;
    }
    return null;
  }

  @override
  Future<User?> register(String email, String password) async {
    final resp = await http.post(Uri.parse('$_baseUrl/register'), headers: _headers(), body: json.encode({'email': email, 'password': password}));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      _token = data['token'];
      final user = User(email: data['user']['email'], name: data['user']['name']);
      return user;
    }
    return null;
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_token == null) return null;
    final resp = await http.get(Uri.parse('$_baseUrl/me'), headers: _headers());
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return User(email: data['email'], name: data['name']);
    }
    return null;
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<List<TravelPlan>> getUserPlans() async {
    final resp = await http.get(Uri.parse('$_baseUrl/plans'), headers: _headers());
    if (resp.statusCode == 200) {
      final List data = json.decode(resp.body);
      return data.map((e) => TravelPlan.fromJson(e)).toList();
    }
    return [];
  }

  @override
  Future<TravelPlan> savePlan(TravelPlan plan) async {
    final resp = await http.post(Uri.parse('$_baseUrl/plans'), headers: _headers(), body: json.encode(plan.toJson()));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return TravelPlan.fromJson(json.decode(resp.body));
    }
    throw Exception('Failed to save plan');
  }

  @override
  Future<TravelPlan?> getPlanById(String id) async {
    final resp = await http.get(Uri.parse('$_baseUrl/plans/$id'), headers: _headers());
    if (resp.statusCode == 200) {
      return TravelPlan.fromJson(json.decode(resp.body));
    }
    return null;
  }

  @override
  Future<String> sharePlan(String planId) async {
    final resp = await http.post(Uri.parse('$_baseUrl/plans/$planId/share'), headers: _headers());
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return data['link'];
    }
    throw Exception('Failed to share plan');
  }
}

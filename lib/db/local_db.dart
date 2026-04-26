import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/models/plan.dart';

class LocalDb {
  LocalDb._internal();
  static final LocalDb instance = LocalDb._internal();
  bool _initialized = false;
  Box<String>? _plansBox;
  Box<String>? _favoritesBox;
  Box<String>? _authBox;
  Box<String>? _friendsBox;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _plansBox = await Hive.openBox<String>('plans');
    _favoritesBox = await Hive.openBox<String>('favorites');
    _authBox = await Hive.openBox<String>('auth');
    _friendsBox = await Hive.openBox<String>('friends');
    _initialized = true;
  }

  Future<List<TravelPlan>> loadPlans() async {
    await init();
    final jsonStr = _plansBox?.get('plans');
    if (jsonStr == null) return [];
    final List decoded = json.decode(jsonStr);
    return decoded
        .map((e) => TravelPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlans(List<TravelPlan> plans) async {
    await init();
    final list = plans.map((p) => p.toJson()).toList();
    await _plansBox?.put('plans', json.encode(list));
  }

  Future<List<String>> loadFavorites() async {
    await init();
    final jsonStr = _favoritesBox?.get('ids');
    if (jsonStr == null) return [];
    return List<String>.from(json.decode(jsonStr));
  }

  Future<void> saveFavorites(List<String> ids) async {
    await init();
    await _favoritesBox?.put('ids', json.encode(ids));
  }

  Future<List<Friend>> loadFriends() async {
    await init();
    final jsonStr = _friendsBox?.get('friends');
    if (jsonStr == null) return [];
    final List decoded = json.decode(jsonStr);
    return decoded
        .map((entry) => Friend.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> saveFriends(List<Friend> friends) async {
    await init();
    final encoded = friends.map((friend) => friend.toJson()).toList();
    await _friendsBox?.put('friends', json.encode(encoded));
  }

  Future<String?> loadProfileCode() async {
    await init();
    return _authBox?.get('profile_code');
  }

  Future<void> saveProfileCode(String code) async {
    await init();
    await _authBox?.put('profile_code', code);
  }
}

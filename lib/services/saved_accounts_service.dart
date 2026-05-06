import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String uid;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime lastSignedInAt;

  const SavedAccount({
    required this.uid,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.lastSignedInAt,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      uid: (json['uid'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      avatarUrl: (json['avatarUrl'] as String?)?.trim(),
      lastSignedInAt:
          DateTime.tryParse(json['lastSignedInAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      if (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
        'avatarUrl': avatarUrl!.trim(),
      'lastSignedInAt': lastSignedInAt.toIso8601String(),
    };
  }
}

class SavedAccountsService {
  static const _storageKey = 'halaph_saved_accounts_v1';

  Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final accounts = decoded
          .whereType<Map>()
          .map((item) => SavedAccount.fromJson(Map<String, dynamic>.from(item)))
          .where(
              (account) => account.uid.isNotEmpty && account.email.isNotEmpty)
          .toList()
        ..sort((a, b) => b.lastSignedInAt.compareTo(a.lastSignedInAt));

      return accounts;
    } catch (error) {
      debugPrint('Failed to load saved accounts: $error');
      return [];
    }
  }

  Future<void> saveCurrentFirebaseUser() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await saveFirebaseUser(user);
  }

  Future<void> saveFirebaseUser(firebase_auth.User user) async {
    final email = user.email?.trim() ?? '';
    if (user.uid.isEmpty || email.isEmpty) return;

    final displayName = user.displayName?.trim();
    final fallbackName = email.split('@').first;

    final account = SavedAccount(
      uid: user.uid,
      email: email,
      name: displayName != null && displayName.isNotEmpty
          ? displayName
          : fallbackName,
      avatarUrl: user.photoURL?.trim(),
      lastSignedInAt: DateTime.now(),
    );

    final accounts = await getSavedAccounts();
    final byUid = <String, SavedAccount>{
      for (final item in accounts) item.uid: item,
    };

    byUid[account.uid] = account;

    final updated = byUid.values.toList()
      ..sort((a, b) => b.lastSignedInAt.compareTo(a.lastSignedInAt));

    await _saveAccounts(updated);
  }

  Future<void> removeSavedAccount(String uid) async {
    final accounts = await getSavedAccounts();
    final updated = accounts.where((account) => account.uid != uid).toList();
    await _saveAccounts(updated);
  }

  Future<void> _saveAccounts(List<SavedAccount> accounts) async {
    final prefs = SharedPreferencesAsync();
    final encoded =
        jsonEncode(accounts.map((account) => account.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

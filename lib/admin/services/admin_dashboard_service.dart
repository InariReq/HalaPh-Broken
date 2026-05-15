import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminDashboardMetric {
  final String value;
  final String subtitle;
  final bool restricted;

  const AdminDashboardMetric({
    required this.value,
    required this.subtitle,
    this.restricted = false,
  });
}

class AdminDashboardStats {
  final DateTime loadedAt;
  final Map<String, AdminDashboardMetric> metrics;

  const AdminDashboardStats({
    required this.loadedAt,
    required this.metrics,
  });

  AdminDashboardMetric metric(String key) {
    return metrics[key] ??
        const AdminDashboardMetric(
          value: '—',
          subtitle: 'No data available.',
        );
  }
}

class AdminDashboardService {
  final FirebaseFirestore _firestore;

  AdminDashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<AdminDashboardStats> loadStats() async {
    final results = await Future.wait<MapEntry<String, AdminDashboardMetric>>([
      _countUserbase(),
      _countCollection(
        key: 'users',
        collectionPath: 'users',
        successSubtitle: 'Registered user profile documents only.',
      ),
      _countCollection(
        key: 'sharedPlans',
        collectionPath: 'sharedPlans',
        successSubtitle: 'Collaborative and saved trip plans.',
      ),
      _countCollection(
        key: 'publicProfiles',
        collectionPath: 'publicProfiles',
        successSubtitle: 'Searchable public friend profiles.',
      ),
      _countCollection(
        key: 'friendCodes',
        collectionPath: 'friendCodes',
        successSubtitle: 'Generated friend invite codes.',
      ),
      _countCollection(
        key: 'locations',
        collectionPath: 'admin_locations',
        successSubtitle: 'Admin-managed location records.',
      ),
      _countCollection(
        key: 'featuredPlaces',
        collectionPath: 'admin_featured_places',
        successSubtitle: 'Admin-managed featured destination records.',
      ),
      _countCollection(
        key: 'ads',
        collectionPath: 'admin_ads',
        successSubtitle: 'Admin-managed advertisement records.',
      ),
      _countCollection(
        key: 'adminUsers',
        collectionPath: 'admin_users',
        successSubtitle: 'Registered admin accounts.',
      ),
      _countQuery(
        key: 'activeAdmins',
        query: _firestore
            .collection('admin_users')
            .where('isActive', isEqualTo: true),
        successSubtitle: 'Admin accounts currently enabled.',
      ),
    ]);

    final metrics = Map<String, AdminDashboardMetric>.fromEntries(results);
    metrics['userbase'] = _buildUserbaseMetric(
      users: metrics['users'],
      publicProfiles: metrics['publicProfiles'],
    );

    return AdminDashboardStats(
      loadedAt: DateTime.now(),
      metrics: metrics,
    );
  }

  AdminDashboardMetric _buildUserbaseMetric({
    required AdminDashboardMetric? users,
    required AdminDashboardMetric? publicProfiles,
  }) {
    final userCount = int.tryParse(users?.value ?? '');
    final publicProfileCount = int.tryParse(publicProfiles?.value ?? '');

    if (userCount == null && publicProfileCount == null) {
      final restricted =
          users?.restricted == true || publicProfiles?.restricted == true;

      debugPrint(
        'Admin dashboard userbase failed: users=${users?.value} '
        'publicProfiles=${publicProfiles?.value}',
      );

      return AdminDashboardMetric(
        value: restricted ? 'Restricted' : '—',
        subtitle: restricted
            ? 'Firestore rules blocked userbase reads.'
            : 'Could not calculate userbase.',
        restricted: restricted,
      );
    }

    final count = math.max(userCount ?? 0, publicProfileCount ?? 0);

    debugPrint(
      'Admin dashboard userbase count: $count '
      '(users=${userCount ?? 0}, publicProfiles=${publicProfileCount ?? 0})',
    );

    return AdminDashboardMetric(
      value: count.toString(),
      subtitle:
          'Estimated app userbase from users and public profiles. Admin accounts are not counted.',
    );
  }

  Future<MapEntry<String, AdminDashboardMetric>> _countUserbase() async {
    try {
      final ids = <String>{};

      final usersSnapshot = await _firestore.collection('users').get().timeout(
            const Duration(seconds: 5),
          );
      for (final doc in usersSnapshot.docs) {
        ids.add(doc.id);
        final uid = doc.data()['uid'];
        if (uid is String && uid.trim().isNotEmpty) {
          ids.add(uid.trim());
        }
      }

      final publicProfilesSnapshot =
          await _firestore.collection('publicProfiles').get().timeout(
                const Duration(seconds: 5),
              );
      for (final doc in publicProfilesSnapshot.docs) {
        final uid = doc.data()['uid'];
        if (uid is String && uid.trim().isNotEmpty) {
          ids.add(uid.trim());
        }
      }

      final friendCodesSnapshot =
          await _firestore.collection('friendCodes').get().timeout(
                const Duration(seconds: 5),
              );
      for (final doc in friendCodesSnapshot.docs) {
        final uid = doc.data()['uid'];
        if (uid is String && uid.trim().isNotEmpty) {
          ids.add(uid.trim());
        }
      }

      debugPrint('Admin dashboard userbase unique count: ${ids.length}');

      return MapEntry(
        'userbase',
        AdminDashboardMetric(
          value: ids.length.toString(),
          subtitle:
              'Unique app users from users, public profiles, and friend codes. Admin accounts are not counted.',
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Admin dashboard userbase failed: ${error.code} ${error.message}',
      );

      if (error.code == 'permission-denied') {
        return const MapEntry(
          'userbase',
          AdminDashboardMetric(
            value: 'Restricted',
            subtitle: 'Firestore rules block userbase reads.',
            restricted: true,
          ),
        );
      }

      return MapEntry(
        'userbase',
        AdminDashboardMetric(
          value: '—',
          subtitle: 'Could not load userbase: ${error.code}.',
        ),
      );
    } on TimeoutException {
      debugPrint('Admin dashboard userbase failed: timed out');

      return const MapEntry(
        'userbase',
        AdminDashboardMetric(
          value: 'Timed out',
          subtitle: 'Firestore did not respond quickly enough.',
        ),
      );
    } catch (error) {
      debugPrint('Admin dashboard userbase failed: $error');

      return const MapEntry(
        'userbase',
        AdminDashboardMetric(
          value: '—',
          subtitle: 'Could not load userbase.',
        ),
      );
    }
  }

  Future<MapEntry<String, AdminDashboardMetric>> _countCollection({
    required String key,
    required String collectionPath,
    required String successSubtitle,
  }) {
    return _countQuery(
      key: key,
      query: _firestore.collection(collectionPath),
      successSubtitle: successSubtitle,
    );
  }

  Future<MapEntry<String, AdminDashboardMetric>> _countQuery({
    required String key,
    required Query<Map<String, dynamic>> query,
    required String successSubtitle,
  }) async {
    try {
      final snapshot = await query.count().get().timeout(
            const Duration(seconds: 5),
          );
      final count = snapshot.count;

      debugPrint('Admin dashboard $key count: ${count ?? 'unknown'}');

      return MapEntry(
        key,
        AdminDashboardMetric(
          value: count == null ? '—' : count.toString(),
          subtitle: successSubtitle,
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Admin dashboard stats failed: $key ${error.code} ${error.message}',
      );

      if (error.code == 'permission-denied') {
        return MapEntry(
          key,
          const AdminDashboardMetric(
            value: 'Restricted',
            subtitle: 'Firestore rules do not allow this admin read yet.',
            restricted: true,
          ),
        );
      }

      return MapEntry(
        key,
        AdminDashboardMetric(
          value: '—',
          subtitle: 'Could not load this metric: ${error.code}.',
        ),
      );
    } on TimeoutException {
      debugPrint('Admin dashboard stats failed: $key timed out');

      return MapEntry(
        key,
        const AdminDashboardMetric(
          value: 'Timed out',
          subtitle: 'Firestore did not respond quickly enough.',
        ),
      );
    } catch (error) {
      debugPrint('Admin dashboard stats failed: $key $error');

      return MapEntry(
        key,
        const AdminDashboardMetric(
          value: '—',
          subtitle: 'Could not load this metric.',
        ),
      );
    }
  }
}

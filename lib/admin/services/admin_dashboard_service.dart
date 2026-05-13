import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

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
      _countCollection(
        key: 'users',
        collectionPath: 'users',
        successSubtitle: 'Registered user profile documents.',
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

    return AdminDashboardStats(
      loadedAt: DateTime.now(),
      metrics: Map.fromEntries(results),
    );
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
      return MapEntry(
        key,
        AdminDashboardMetric(
          value: count == null ? '—' : count.toString(),
          subtitle: successSubtitle,
        ),
      );
    } on FirebaseException catch (error) {
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
      return MapEntry(
        key,
        const AdminDashboardMetric(
          value: 'Timed out',
          subtitle: 'Firestore did not respond quickly enough.',
        ),
      );
    } catch (_) {
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

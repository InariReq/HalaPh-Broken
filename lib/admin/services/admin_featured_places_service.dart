import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/utils/place_display_name_utils.dart';

import '../models/admin_featured_place.dart';

class AdminFeatureCandidate {
  final String sourceLabel;
  final String collectionPath;
  final String documentId;
  final String name;
  final String displayName;
  final String originalName;
  final String address;
  final String category;
  final String description;
  final String imageUrl;
  final double? latitude;
  final double? longitude;
  final String googlePlaceId;
  final String googlePhotoReference;
  final bool isGoogleResult;
  final bool isFeatured;
  final int featuredPriority;

  const AdminFeatureCandidate({
    required this.sourceLabel,
    required this.collectionPath,
    required this.documentId,
    required this.name,
    String? displayName,
    this.originalName = '',
    required this.address,
    required this.category,
    this.description = '',
    this.imageUrl = '',
    this.latitude,
    this.longitude,
    this.googlePlaceId = '',
    this.googlePhotoReference = '',
    this.isGoogleResult = false,
    this.isFeatured = false,
    this.featuredPriority = 999,
  }) : displayName = displayName ?? name;

  String get sourceId =>
      isGoogleResult ? googlePlaceId : '$collectionPath/$documentId';
}

class AdminFeatureSearchResult {
  final List<AdminFeatureCandidate> candidates;
  final int savedResultCount;
  final int googleResultCount;
  final bool googleUnavailable;
  final Map<String, int> sourceCounts;
  final Map<String, String> sourceFailures;
  final List<String> failures;

  const AdminFeatureSearchResult({
    required this.candidates,
    required this.savedResultCount,
    required this.googleResultCount,
    required this.googleUnavailable,
    required this.sourceCounts,
    required this.sourceFailures,
    required this.failures,
  });

  bool get appPlacesBlocked {
    for (final source in const ['destinations', 'places', 'locations']) {
      if ((sourceFailures[source] ?? '').contains('permission-denied')) {
        return true;
      }
    }
    return false;
  }

  bool get hasPermissionDenied {
    return sourceFailures.values.any((failure) {
      return failure.contains('permission-denied');
    });
  }

  String sourceLabel(String source) {
    if ((sourceFailures[source] ?? '').contains('permission-denied')) {
      return 'blocked';
    }
    return (sourceCounts[source] ?? 0).toString();
  }

  String googleLabel() {
    if (googleUnavailable) return 'unavailable';
    return googleResultCount.toString();
  }
}

class AdminFeaturedPlacesService {
  final FirebaseFirestore _firestore;
  static const _adminLocationsCollection = 'admin_locations';
  static const _destinationCollections = <String>[
    'destinations',
    'places',
    'locations',
    'cached_destinations',
  ];
  static const _defaultGoogleSearchLocation = LatLng(14.5995, 120.9842);

  AdminFeaturedPlacesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_featured_places');

  Stream<List<AdminFeaturedPlace>> watchFeaturedPlaces() {
    return _collection.orderBy('priority').snapshots().map((snapshot) {
      final places = snapshot.docs
          .map(AdminFeaturedPlace.fromSnapshot)
          .toList(growable: false);
      final sorted = [...places]..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return sorted;
    });
  }

  Future<void> createFeaturedPlace({
    required AdminFeaturedPlace place,
    required String actorUid,
  }) async {
    await _collection.add(place.toCreateMap(actorUid: actorUid));
  }

  Future<void> updateFeaturedPlace({
    required AdminFeaturedPlace place,
    required String actorUid,
  }) async {
    await _collection
        .doc(place.id)
        .update(place.toUpdateMap(actorUid: actorUid));
  }

  Future<void> setActive({
    required String placeId,
    required bool isActive,
    required String actorUid,
  }) async {
    await _collection.doc(placeId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }

  Future<void> deleteFeaturedPlace({required String placeId}) async {
    debugPrint('Admin delete requested: admin_featured_places/$placeId');
    debugPrint('Admin delete confirmed: admin_featured_places/$placeId');
    try {
      await _collection.doc(placeId).delete();
      debugPrint('Admin delete succeeded: admin_featured_places/$placeId');
    } catch (error) {
      debugPrint('Admin delete failed: admin_featured_places/$placeId $error');
      rethrow;
    }
  }

  Future<List<AdminFeatureCandidate>> searchFeatureCandidates(
    String query,
  ) async {
    final result = await searchFeatureCandidatesDetailed(query);
    return result.candidates;
  }

  Future<AdminFeatureSearchResult> searchFeatureCandidatesDetailed(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const AdminFeatureSearchResult(
        candidates: <AdminFeatureCandidate>[],
        savedResultCount: 0,
        googleResultCount: 0,
        googleUnavailable: false,
        sourceCounts: <String, int>{},
        sourceFailures: <String, String>{},
        failures: <String>[],
      );
    }

    final candidates = <AdminFeatureCandidate>[];
    final sourceCounts = <String, int>{};
    final sourceFailures = <String, String>{};
    final failures = <String>[];
    var savedResultCount = 0;

    final adminLocationResults = await _searchFirestoreCollection(
      collectionPath: _adminLocationsCollection,
      sourceLabel: 'Admin Location',
      query: trimmed,
    );
    if (adminLocationResults.failure != null) {
      failures.add(adminLocationResults.failure!);
      sourceFailures[_adminLocationsCollection] = adminLocationResults.failure!;
    }
    debugPrint(
      'Admin featured search admin_locations results: ${adminLocationResults.candidates.length}',
    );
    sourceCounts[_adminLocationsCollection] =
        adminLocationResults.candidates.length;
    savedResultCount += adminLocationResults.candidates.length;
    candidates.addAll(adminLocationResults.candidates);

    for (final collectionPath in _destinationCollections) {
      final results = await _searchFirestoreCollection(
        collectionPath: collectionPath,
        sourceLabel: collectionPath,
        query: trimmed,
      );
      if (results.failure != null) failures.add(results.failure!);
      if (results.failure != null) {
        sourceFailures[collectionPath] = results.failure!;
      }
      debugPrint(
        'Admin featured search $collectionPath results: ${results.candidates.length}',
      );
      sourceCounts[collectionPath] = results.candidates.length;
      savedResultCount += results.candidates.length;
      candidates.addAll(results.candidates);
    }

    var googleUnavailable = false;
    var googleResultCount = 0;
    try {
      final googleResults = await GoogleMapsService.searchPlacesNearbyDetailed(
        location: _defaultGoogleSearchLocation,
        query: trimmed,
        radius: 50000,
        limit: 8,
      );
      googleUnavailable = googleResults.isUnavailable;
      if (googleResults.failure != null) {
        failures.add(googleResults.failure!);
        debugPrint(
            'Admin featured Google search failed: ${googleResults.failure}');
      }
      if (googleResults.photoFailure != null) {
        failures.add(googleResults.photoFailure!);
        debugPrint(
          'Admin featured Google photo unavailable: ${googleResults.photoFailure}',
        );
      }
      googleResultCount = googleResults.destinations.length;
      debugPrint('Admin featured search google results: $googleResultCount');
      for (final destination in googleResults.destinations) {
        candidates.add(_googleCandidate(destination));
      }
    } catch (error) {
      googleUnavailable = true;
      failures.add('Google search failed: $error');
      debugPrint('Admin featured Google search failed: $error');
      debugPrint('Admin featured search google results: 0');
    }
    sourceCounts['Google'] = googleResultCount;

    final merged = _dedupeCandidates(candidates);
    debugPrint('Admin featured search total results: ${merged.length}');
    return AdminFeatureSearchResult(
      candidates: merged,
      savedResultCount: savedResultCount,
      googleResultCount: googleResultCount,
      googleUnavailable: googleUnavailable,
      sourceCounts: Map.unmodifiable(sourceCounts),
      sourceFailures: Map.unmodifiable(sourceFailures),
      failures: List.unmodifiable(failures),
    );
  }

  Future<void> featureExistingPlace({
    required AdminFeatureCandidate candidate,
    required int featuredPriority,
    String displayNameOverride = '',
    required String actorUid,
  }) async {
    debugPrint(
      'Admin feature existing place selected: '
      '${candidate.sourceLabel} ${candidate.sourceId}',
    );

    if (candidate.isGoogleResult) {
      await _importGoogleCandidate(
        candidate: candidate,
        featuredPriority: featuredPriority,
        displayNameOverride: displayNameOverride,
        actorUid: actorUid,
      );
      return;
    }

    if (candidate.collectionPath != _adminLocationsCollection) {
      await _upsertFeaturedReference(
        candidate: candidate,
        featuredPriority: featuredPriority,
        displayNameOverride: displayNameOverride,
        actorUid: actorUid,
      );
      return;
    }

    await _firestore
        .collection(candidate.collectionPath)
        .doc(candidate.documentId)
        .update({
      'isFeatured': true,
      'featuredPriority': featuredPriority,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
    debugPrint(
      'Admin existing place updated as featured: '
      '${candidate.collectionPath}/${candidate.documentId}',
    );
  }

  Future<void> unfeatureExistingPlace({
    required AdminFeatureCandidate candidate,
    required String actorUid,
  }) async {
    final target = candidate.isGoogleResult
        ? await _findMatchingAdminLocation(candidate)
        : _ExistingAdminLocation(
            id: candidate.documentId,
            data: const <String, dynamic>{},
          );
    final collectionPath = candidate.isGoogleResult
        ? _adminLocationsCollection
        : candidate.collectionPath;
    if (!candidate.isGoogleResult &&
        candidate.collectionPath != _adminLocationsCollection) {
      final referenceId = _featuredReferenceDocId(candidate);
      await _collection.doc(referenceId).set({
        'isActive': false,
        'isFeatured': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actorUid,
      }, SetOptions(merge: true));
      debugPrint('Admin place unfeatured: admin_featured_places/$referenceId');
      return;
    }
    if (target == null) {
      debugPrint(
        'Admin place unfeatured: $collectionPath/${candidate.sourceId} not found',
      );
      return;
    }
    await _firestore.collection(collectionPath).doc(target.id).update({
      'isFeatured': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
    debugPrint('Admin place unfeatured: $collectionPath/${target.id}');
  }

  Future<void> _upsertFeaturedReference({
    required AdminFeatureCandidate candidate,
    required int featuredPriority,
    required String displayNameOverride,
    required String actorUid,
  }) async {
    final referenceId = _featuredReferenceDocId(candidate);
    final doc = _collection.doc(referenceId);
    final snapshot = await doc.get();
    final cleanedDisplayName = candidate.displayName.trim();
    final editedDisplayName = displayNameOverride.trim();
    final originalName = candidate.originalName.trim();
    final shouldSaveOverride = PlaceDisplayNameUtils.isAdminEditedOverride(
      value: editedDisplayName,
      prefilledValue: cleanedDisplayName,
    );
    await doc.set({
      'sourceCollection': candidate.collectionPath,
      'sourceId': candidate.documentId,
      'targetId': candidate.documentId,
      'displayNameOverride':
          shouldSaveOverride ? editedDisplayName : FieldValue.delete(),
      if (cleanedDisplayName.isNotEmpty) 'displayName': cleanedDisplayName,
      if (originalName.isNotEmpty) 'originalName': originalName,
      if (originalName.isNotEmpty) 'googleName': originalName,
      if (originalName.isNotEmpty) 'rawName': originalName,
      'isActive': true,
      'isFeatured': true,
      'featuredPriority': featuredPriority,
      'priority': featuredPriority,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdBy': actorUid,
    }, SetOptions(merge: true));
    debugPrint(
      'Admin existing place updated as featured: '
      '${candidate.collectionPath}/${candidate.documentId}',
    );
  }

  Future<_AdminSourceSearchResult> _searchFirestoreCollection({
    required String collectionPath,
    required String sourceLabel,
    required String query,
  }) async {
    try {
      final snapshot =
          await _firestore.collection(collectionPath).limit(250).get();
      final normalizedQuery = _normalize(query);
      final candidates = snapshot.docs
          .map((doc) => _candidateFromDoc(
                collectionPath: collectionPath,
                sourceLabel: sourceLabel,
                doc: doc,
              ))
          .whereType<AdminFeatureCandidate>()
          .where((candidate) {
        final searchable = _normalize(
          '${candidate.name} ${candidate.originalName} ${candidate.address} ${candidate.category} '
          '${candidate.description} ${candidate.googlePlaceId} '
          '${candidate.documentId}',
        );
        return searchable.contains(normalizedQuery);
      }).toList(growable: false);
      return _AdminSourceSearchResult(candidates: candidates);
    } on FirebaseException catch (error) {
      final failure =
          '$collectionPath ${error.code} ${error.message ?? ''}'.trim();
      debugPrint(
        'Admin featured search source failed: '
        '$failure',
      );
      return _AdminSourceSearchResult(
        candidates: const <AdminFeatureCandidate>[],
        failure: failure,
      );
    } catch (error) {
      final failure = '$collectionPath unknown $error';
      debugPrint(
        'Admin featured search source failed: $failure',
      );
      return _AdminSourceSearchResult(
        candidates: const <AdminFeatureCandidate>[],
        failure: failure,
      );
    }
  }

  AdminFeatureCandidate? _candidateFromDoc({
    required String collectionPath,
    required String sourceLabel,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final originalNameValue = PlaceDisplayNameUtils.originalName(data);
    final originalName = originalNameValue.isEmpty ? doc.id : originalNameValue;
    final cleanRawName = collectionPath == 'cached_destinations' ||
        _stringValue(data['source']).toLowerCase() == 'google';
    final displayName = PlaceDisplayNameUtils.resolveDisplayName(
      data,
      cleanRawName: cleanRawName,
    );
    final name = displayName.isEmpty ? originalName : displayName;
    final address = _stringValue(
      data['address'] ??
          data['formattedAddress'] ??
          data['formatted_address'] ??
          data['location'] ??
          data['vicinity'] ??
          data['subtitle'] ??
          data['city'],
    );
    final city = _stringValue(data['city']);
    final province = _stringValue(data['province']);
    final category = _stringValue(data['category'] ?? data['type']);
    final googlePlaceId =
        _stringValue(data['googlePlaceId'] ?? data['placeId']);
    final coords = _readCoordinates(data);
    return AdminFeatureCandidate(
      sourceLabel: _sourceLabel(sourceLabel, data),
      collectionPath: collectionPath,
      documentId: doc.id,
      name: name,
      displayName: name,
      originalName: originalName,
      address: _displayAddress(address, city, province),
      category: category.isEmpty ? 'landmark' : category,
      description: _stringValue(data['description']),
      imageUrl: _stringValue(
        data['imageUrl'] ??
            data['image'] ??
            data['image_url'] ??
            data['photoUrl'] ??
            data['photoURL'] ??
            data['thumbnailUrl'] ??
            data['thumbnail'] ??
            data['coverImageUrl'] ??
            data['bannerImage'] ??
            data['googlePhotoUrl'],
      ),
      latitude: coords?.latitude,
      longitude: coords?.longitude,
      googlePlaceId: googlePlaceId,
      googlePhotoReference: _stringValue(
        data['googlePhotoReference'] ??
            data['photoReference'] ??
            data['photo_reference'] ??
            data['google_photo_reference'],
      ),
      isFeatured: data['isFeatured'] == true || data['featured'] == true,
      featuredPriority: _readPriority(data),
    );
  }

  AdminFeatureCandidate _googleCandidate(Destination destination) {
    final coordinates = destination.coordinates;
    final photoReference =
        _tagValue(destination.tags, 'googlePhotoReference:') ??
            _tagValue(destination.tags, 'photoReference:') ??
            '';
    if (photoReference.isNotEmpty) {
      debugPrint('Google place photo reference found: ${destination.id}');
    } else {
      debugPrint('Google place photo reference missing: ${destination.id}');
    }
    final displayName =
        PlaceDisplayNameUtils.cleanGoogleDisplayName(destination.name);
    return AdminFeatureCandidate(
      sourceLabel: 'Google',
      collectionPath: '',
      documentId: '',
      name: displayName.isEmpty ? destination.name : displayName,
      displayName: displayName.isEmpty ? destination.name : displayName,
      originalName: destination.name,
      address: destination.location,
      category: destination.category.name,
      description: destination.description,
      imageUrl: destination.imageUrl,
      latitude: coordinates?.latitude,
      longitude: coordinates?.longitude,
      googlePlaceId: destination.id,
      googlePhotoReference: photoReference,
      isGoogleResult: true,
    );
  }

  Future<void> _importGoogleCandidate({
    required AdminFeatureCandidate candidate,
    required int featuredPriority,
    required String displayNameOverride,
    required String actorUid,
  }) async {
    final existing = await _findMatchingAdminLocation(candidate);
    final imageUrl = candidate.imageUrl.isNotEmpty
        ? candidate.imageUrl
        : GoogleMapsService.buildPhotoUrl(candidate.googlePhotoReference);
    if (imageUrl.isNotEmpty && candidate.googlePhotoReference.isNotEmpty) {
      debugPrint('Google photo URL built: ${candidate.googlePlaceId}');
    }
    final originalName = candidate.originalName.isEmpty
        ? candidate.name
        : candidate.originalName;
    final editedDisplayName = displayNameOverride.trim();
    final shouldSaveOverride = PlaceDisplayNameUtils.isAdminEditedOverride(
      value: editedDisplayName,
      prefilledValue: candidate.displayName,
    );
    final data = {
      'name': originalName,
      'title': originalName,
      'displayName': candidate.displayName,
      'displayNameOverride':
          shouldSaveOverride ? editedDisplayName : FieldValue.delete(),
      'originalName': originalName,
      'googleName': originalName,
      'rawName': originalName,
      'city': candidate.address.isEmpty ? 'Google Places' : candidate.address,
      'province': '',
      'category': candidate.category,
      'description': candidate.description.isEmpty
          ? candidate.address
          : candidate.description,
      'latitude': candidate.latitude,
      'longitude': candidate.longitude,
      'imageUrl': imageUrl,
      'googlePhotoUrl': imageUrl,
      'googlePhotoReference': candidate.googlePhotoReference,
      'googlePlaceId': candidate.googlePlaceId,
      'placeId': candidate.googlePlaceId,
      'source': 'google',
      'priority': 10,
      'isActive': true,
      'isFeatured': true,
      'featuredPriority': featuredPriority,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };

    if (existing != null) {
      await _firestore
          .collection(_adminLocationsCollection)
          .doc(existing.id)
          .update(data);
      debugPrint(
        'Admin featured place duplicate avoided: '
        'updated admin_locations/${existing.id}',
      );
      debugPrint(
        'Admin Google place imported for featured: '
        '${candidate.googlePlaceId.isEmpty ? candidate.name : candidate.googlePlaceId}',
      );
      return;
    }

    final doc = await _firestore.collection(_adminLocationsCollection).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
    });
    debugPrint(
      'Admin Google place imported for featured: '
      '${candidate.googlePlaceId.isEmpty ? candidate.name : candidate.googlePlaceId}',
    );
    debugPrint(
        'Admin existing place updated as featured: admin_locations/${doc.id}');
  }

  Future<_ExistingAdminLocation?> _findMatchingAdminLocation(
    AdminFeatureCandidate candidate,
  ) async {
    final googlePlaceId = candidate.googlePlaceId.trim();
    if (googlePlaceId.isNotEmpty) {
      for (final field in const ['googlePlaceId', 'placeId']) {
        final snapshot = await _firestore
            .collection(_adminLocationsCollection)
            .where(field, isEqualTo: googlePlaceId)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return _ExistingAdminLocation(
            id: snapshot.docs.first.id,
            data: snapshot.docs.first.data(),
          );
        }
      }
    }

    final snapshot =
        await _firestore.collection(_adminLocationsCollection).limit(200).get();
    final candidateName = _normalize(candidate.name);
    final candidateBucket =
        _coordinateBucket(candidate.latitude, candidate.longitude);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = _normalize(data['name']);
      if (candidateName.isNotEmpty && name == candidateName) {
        return _ExistingAdminLocation(id: doc.id, data: data);
      }

      final coords = _readCoordinates(data);
      final bucket = _coordinateBucket(coords?.latitude, coords?.longitude);
      if (candidateBucket.isNotEmpty && bucket == candidateBucket) {
        return _ExistingAdminLocation(id: doc.id, data: data);
      }
    }

    return null;
  }

  List<AdminFeatureCandidate> _dedupeCandidates(
    List<AdminFeatureCandidate> candidates,
  ) {
    final out = <AdminFeatureCandidate>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      final keys = _candidateDedupeKeys(candidate);
      if (keys.any(seen.contains)) {
        debugPrint(
          'Admin featured place duplicate avoided: '
          '${candidate.sourceId.isEmpty ? candidate.name : candidate.sourceId}',
        );
        continue;
      }
      seen.addAll(keys);
      out.add(candidate);
    }

    return out;
  }

  Set<String> _candidateDedupeKeys(AdminFeatureCandidate candidate) {
    final keys = <String>{};
    if (candidate.sourceId.trim().isNotEmpty) {
      keys.add('source:${candidate.sourceId.toLowerCase()}');
    }
    if (candidate.googlePlaceId.trim().isNotEmpty) {
      keys.add('google:${candidate.googlePlaceId.trim().toLowerCase()}');
    }
    final name = _normalize(candidate.name);
    if (name.isNotEmpty) keys.add('name:$name');
    final bucket = _coordinateBucket(candidate.latitude, candidate.longitude);
    if (bucket.isNotEmpty) keys.add('coords:$bucket');
    return keys;
  }

  String _featuredReferenceDocId(AdminFeatureCandidate candidate) {
    final raw = 'ref_${candidate.collectionPath}_${candidate.documentId}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  String _sourceLabel(String fallback, Map<String, dynamic> data) {
    final source = _stringValue(data['source']);
    if (source.isEmpty) return fallback;
    if (source.toLowerCase() == 'google') return 'Google';
    if (source.toLowerCase() == 'manual_search') return 'Manual placeholder';
    return source;
  }

  String? _tagValue(List<String> tags, String prefix) {
    final normalizedPrefix = prefix.toLowerCase();
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.toLowerCase().startsWith(normalizedPrefix)) {
        final value = trimmed.substring(prefix.length).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  String _displayAddress(String address, String city, String province) {
    if (address.isNotEmpty) return address;
    if (city.isNotEmpty && province.isNotEmpty) return '$city, $province';
    if (city.isNotEmpty) return city;
    if (province.isNotEmpty) return province;
    return 'Saved place';
  }

  int _readPriority(Map<String, dynamic> data) {
    final featuredPriority = data['featuredPriority'];
    if (featuredPriority is int) return featuredPriority;
    if (featuredPriority is num) return featuredPriority.round();

    final priority = data['priority'];
    if (priority is int) return priority;
    if (priority is num) return priority.round();
    return 999;
  }

  String _stringValue(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  LatLng? _readCoordinates(Map<String, dynamic> data) {
    final latitude = _readDouble(data['latitude'] ?? data['lat']);
    final longitude = _readDouble(data['longitude'] ?? data['lng']);
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }

    final coordinates = data['coordinates'];
    if (coordinates is GeoPoint) {
      return LatLng(coordinates.latitude, coordinates.longitude);
    }
    if (coordinates is Map) {
      final lat = _readDouble(coordinates['latitude'] ?? coordinates['lat']);
      final lng = _readDouble(coordinates['longitude'] ?? coordinates['lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    return null;
  }

  double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  String _coordinateBucket(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return '';
    return '${(latitude * 10000).round()},${(longitude * 10000).round()}';
  }

  String _normalize(Object? value) {
    if (value == null) return '';
    return value
        .toString()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }
}

class _ExistingAdminLocation {
  final String id;
  final Map<String, dynamic> data;

  const _ExistingAdminLocation({
    required this.id,
    required this.data,
  });
}

class _AdminSourceSearchResult {
  final List<AdminFeatureCandidate> candidates;
  final String? failure;

  const _AdminSourceSearchResult({
    required this.candidates,
    this.failure,
  });
}

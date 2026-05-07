import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halaph/models/destination.dart';

class ParticipantStartLocation {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final dynamic updatedAt;

  const ParticipantStartLocation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  factory ParticipantStartLocation.fromJson(Map<String, dynamic> json) {
    final latitude = TravelPlan._parseDouble(json['latitude']);
    final longitude = TravelPlan._parseDouble(json['longitude']);

    if (latitude == null || longitude == null) {
      throw FormatException('Invalid participant start location coordinates');
    }

    return ParticipantStartLocation(
      name: (json['name'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      latitude: latitude,
      longitude: longitude,
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class TravelPlan {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participantUids;
  final String createdBy;
  final List<DayItinerary> itinerary;
  final bool isShared;
  final String? bannerImage;
  final String? meetingPointName;
  final String? meetingPointAddress;
  final double? meetingPointLatitude;
  final double? meetingPointLongitude;
  final Map<String, ParticipantStartLocation> participantStartLocations;
  final List<String> collaboratorUids;
  final String status;

  TravelPlan({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.participantUids,
    required this.createdBy,
    this.itinerary = const [],
    this.isShared = false,
    this.bannerImage,
    this.meetingPointName,
    this.meetingPointAddress,
    this.meetingPointLatitude,
    this.meetingPointLongitude,
    this.participantStartLocations = const {},
    this.collaboratorUids = const [],
    this.status = 'active',
  });

  static String _parseStatus(dynamic value) {
    final status = value is String ? value.trim().toLowerCase() : '';
    return status.isEmpty ? 'active' : status;
  }

  bool get isFinished => status == 'finished' || status == 'completed';

  bool get isActive => !isFinished;

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static Map<String, ParticipantStartLocation> _parseParticipantStartLocations(
    dynamic value,
  ) {
    if (value is! Map) return const {};

    final parsed = <String, ParticipantStartLocation>{};

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final rawLocation = entry.value;

      if (key.isEmpty || rawLocation is! Map) continue;

      try {
        parsed[key] = ParticipantStartLocation.fromJson(
          Map<String, dynamic>.from(rawLocation),
        );
      } catch (_) {
        continue;
      }
    }

    return parsed;
  }

  factory TravelPlan.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return TravelPlan(
      id: json['id'] as String? ?? '',
      title: (json['title'] as String? ?? '').trim(),
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      participantUids: List<String>.from(
          json['participantUids'] ?? json['participantIds'] ?? []),
      createdBy:
          (json['createdBy'] as String? ?? json['ownerUid'] as String? ?? '')
              .trim(),
      itinerary: (json['itinerary'] as List?)
              ?.map((e) => DayItinerary.fromJson(e))
              .toList() ??
          [],
      isShared: json['isShared'] ?? false,
      bannerImage: (json['bannerImage'] as String?)?.trim(),
      meetingPointName: (json['meetingPointName'] as String?)?.trim(),
      meetingPointAddress: (json['meetingPointAddress'] as String?)?.trim(),
      meetingPointLatitude: _parseDouble(json['meetingPointLatitude']),
      meetingPointLongitude: _parseDouble(json['meetingPointLongitude']),
      participantStartLocations:
          _parseParticipantStartLocations(json['participantStartLocations']),
      collaboratorUids: List<String>.from(json['collaboratorUids'] ?? []),
      status: _parseStatus(json['status']),
    );
  }

  /// Create TravelPlan from Firestore data, using provided id.
  /// This is the helper for tests and fromFirestore.
  static TravelPlan fromFirestoreData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return TravelPlan(
      id: id,
      title: (data['title'] as String? ?? '').trim(),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      participantUids: List<String>.from(
          data['participantUids'] ?? data['participantIds'] ?? []),
      createdBy:
          (data['createdBy'] as String? ?? data['ownerUid'] as String? ?? '')
              .trim(),
      itinerary: (data['itinerary'] as List?)
              ?.map((e) => DayItinerary.fromJson(e))
              .toList() ??
          [],
      isShared: data['isShared'] ?? false,
      bannerImage: (data['bannerImage'] as String?)?.trim(),
      meetingPointName: (data['meetingPointName'] as String?)?.trim(),
      meetingPointAddress: (data['meetingPointAddress'] as String?)?.trim(),
      meetingPointLatitude: _parseDouble(data['meetingPointLatitude']),
      meetingPointLongitude: _parseDouble(data['meetingPointLongitude']),
      participantStartLocations:
          _parseParticipantStartLocations(data['participantStartLocations']),
      collaboratorUids: List<String>.from(data['collaboratorUids'] ?? []),
      status: _parseStatus(data['status']),
    );
  }

  /// Create TravelPlan from Firestore document, using doc.id as the plan ID.
  /// Delegates to fromFirestoreData.
  factory TravelPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TravelPlan.fromFirestoreData(id: doc.id, data: data);
  }

  Map<String, dynamic> toJson() {
    final data = {
      // Do NOT include 'id' - not in planFields() firestore.rules
      'title': title.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdBy': createdBy.trim(),
      'ownerUid': createdBy.trim(),
      'ownerId': createdBy.trim(),
      'participantUids': participantUids.map((e) => e.trim()).toList(),
      'collaboratorUids': collaboratorUids.map((e) => e.trim()).toList(),
      'itinerary': itinerary.map((e) => e.toJson()).toList(),
      'isShared': isShared,
      'status': status.trim().isEmpty ? 'active' : status.trim(),
      if (bannerImage?.isNotEmpty == true) 'bannerImage': bannerImage!.trim(),
      if (meetingPointName?.trim().isNotEmpty == true)
        'meetingPointName': meetingPointName!.trim(),
      if (meetingPointAddress?.trim().isNotEmpty == true)
        'meetingPointAddress': meetingPointAddress!.trim(),
      if (meetingPointLatitude != null)
        'meetingPointLatitude': meetingPointLatitude,
      if (meetingPointLongitude != null)
        'meetingPointLongitude': meetingPointLongitude,
      if (participantStartLocations.isNotEmpty)
        'participantStartLocations': {
          for (final entry in participantStartLocations.entries)
            if (entry.key.trim().isNotEmpty)
              entry.key.trim(): entry.value.toJson(),
        },
    };
    return data;
  }

  String get formattedDateRange {
    final start = '${startDate.month}/${startDate.day}/${startDate.year}';
    final end = '${endDate.month}/${endDate.day}/${endDate.year}';
    return '$start - $end';
  }

  int get totalDays => endDate.difference(startDate).inDays + 1;
}

class DayItinerary {
  final DateTime date;
  final List<ItineraryItem> items;

  DayItinerary({
    required this.date,
    this.items = const [],
  });

  factory DayItinerary.fromJson(Map<String, dynamic> json) {
    return DayItinerary(
      date: DateTime.parse(json['date']),
      items: (json['items'] as List?)
              ?.map((e) => ItineraryItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  String get formattedDate => '${date.month}/${date.day}';
  String get dayName => 'Day ${items.isNotEmpty ? items.first.dayNumber : 1}';
}

class ItineraryItem {
  final String id;
  final Destination destination;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String notes;
  final int dayNumber;
  final List<String> transportOptions;

  ItineraryItem({
    required this.id,
    required this.destination,
    required this.startTime,
    required this.endTime,
    this.notes = '',
    required this.dayNumber,
    this.transportOptions = const [],
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'],
      destination: Destination.fromJson(json['destination']),
      startTime: TimeOfDay(
        hour: json['startHour'] ?? 0,
        minute: json['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] ?? 0,
        minute: json['endMinute'] ?? 0,
      ),
      notes: json['notes'] ?? '',
      dayNumber: json['dayNumber'] ?? 1,
      transportOptions: List<String>.from(json['transportOptions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination.toJson(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'notes': notes,
      'dayNumber': dayNumber,
      'transportOptions': transportOptions,
    };
  }

  String get formattedStartTime =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
}

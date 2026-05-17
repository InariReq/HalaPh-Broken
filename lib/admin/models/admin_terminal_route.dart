import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTerminalRoute {
  final String id;

  // Terminal Information
  final String terminalName;
  final String terminalAddress;
  final String city;
  final double latitude;
  final double longitude;
  final String terminalType;
  final String terminalPhotoUrl;
  final String landmarkNotes;

  // Route Information
  final String originTerminal;
  final String destination;
  final String via;
  final String routeName;
  final String operatorName;
  final String busType;
  final double? fareMin;
  final double? fareMax;
  final String scheduleText;
  final String firstTrip;
  final String lastTrip;
  final String frequencyText;
  final String boardingGate;
  final String dropOffPoint;

  // Verification
  final String sourceType;
  final String sourceName;
  final String sourceUrl;
  final String sourceScreenshotUrl;
  final String verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? lastCheckedAt;
  final String confidenceLevel;
  final String status;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminTerminalRoute({
    required this.id,
    required this.terminalName,
    required this.terminalAddress,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.terminalType,
    this.terminalPhotoUrl = '',
    this.landmarkNotes = '',
    required this.originTerminal,
    required this.destination,
    this.via = '',
    this.routeName = '',
    this.operatorName = '',
    this.busType = '',
    this.fareMin,
    this.fareMax,
    this.scheduleText = '',
    this.firstTrip = '',
    this.lastTrip = '',
    this.frequencyText = '',
    this.boardingGate = '',
    this.dropOffPoint = '',
    required this.sourceType,
    this.sourceName = '',
    this.sourceUrl = '',
    this.sourceScreenshotUrl = '',
    this.verifiedBy = '',
    this.verifiedAt,
    this.lastCheckedAt,
    required this.confidenceLevel,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminTerminalRoute.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminTerminalRoute(
      id: doc.id,
      terminalName: _readString(data['terminalName']),
      terminalAddress: _readString(data['terminalAddress']),
      city: _readString(data['city']),
      latitude: _readDouble(data['latitude']) ?? 0,
      longitude: _readDouble(data['longitude']) ?? 0,
      terminalType: _readString(data['terminalType']),
      terminalPhotoUrl: _readString(data['terminalPhotoUrl']),
      landmarkNotes: _readString(data['landmarkNotes']),
      originTerminal: _readString(data['originTerminal']),
      destination: _readString(data['destination']),
      via: _readString(data['via']),
      routeName: _readString(data['routeName']),
      operatorName: _readString(data['operatorName']),
      busType: _readString(data['busType']),
      fareMin: _readDouble(data['fareMin']),
      fareMax: _readDouble(data['fareMax']),
      scheduleText: _readString(data['scheduleText']),
      firstTrip: _readString(data['firstTrip']),
      lastTrip: _readString(data['lastTrip']),
      frequencyText: _readString(data['frequencyText']),
      boardingGate: _readString(data['boardingGate']),
      dropOffPoint: _readString(data['dropOffPoint']),
      sourceType: _readString(data['sourceType']),
      sourceName: _readString(data['sourceName']),
      sourceUrl: _readString(data['sourceUrl']),
      sourceScreenshotUrl: _readString(data['sourceScreenshotUrl']),
      verifiedBy: _readString(data['verifiedBy']),
      verifiedAt: _timestampToDate(data['verifiedAt']),
      lastCheckedAt: _timestampToDate(data['lastCheckedAt']),
      confidenceLevel: _readString(data['confidenceLevel']),
      status: _readString(data['status']),
      createdAt: _timestampToDate(data['createdAt']) ?? _epoch,
      updatedAt: _timestampToDate(data['updatedAt']) ?? _epoch,
    );
  }

  Map<String, Object?> toCreateMap() {
    final now = FieldValue.serverTimestamp();
    return {
      'terminalName': terminalName,
      'terminalAddress': terminalAddress,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'terminalType': terminalType,
      'terminalPhotoUrl': terminalPhotoUrl,
      'landmarkNotes': landmarkNotes,
      'originTerminal': originTerminal,
      'destination': destination,
      'via': via,
      'routeName': routeName,
      'operatorName': operatorName,
      'busType': busType,
      'fareMin': fareMin,
      'fareMax': fareMax,
      'scheduleText': scheduleText,
      'firstTrip': firstTrip,
      'lastTrip': lastTrip,
      'frequencyText': frequencyText,
      'boardingGate': boardingGate,
      'dropOffPoint': dropOffPoint,
      'sourceType': sourceType,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'sourceScreenshotUrl': sourceScreenshotUrl,
      'verifiedBy': verifiedBy,
      'verifiedAt': _dateToTimestamp(verifiedAt),
      'lastCheckedAt': _dateToTimestamp(lastCheckedAt),
      'confidenceLevel': confidenceLevel,
      'status': status,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  Map<String, Object?> toUpdateMap() {
    return {
      'terminalName': terminalName,
      'terminalAddress': terminalAddress,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'terminalType': terminalType,
      'terminalPhotoUrl': terminalPhotoUrl,
      'landmarkNotes': landmarkNotes,
      'originTerminal': originTerminal,
      'destination': destination,
      'via': via,
      'routeName': routeName,
      'operatorName': operatorName,
      'busType': busType,
      'fareMin': fareMin,
      'fareMax': fareMax,
      'scheduleText': scheduleText,
      'firstTrip': firstTrip,
      'lastTrip': lastTrip,
      'frequencyText': frequencyText,
      'boardingGate': boardingGate,
      'dropOffPoint': dropOffPoint,
      'sourceType': sourceType,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'sourceScreenshotUrl': sourceScreenshotUrl,
      'verifiedBy': verifiedBy,
      'verifiedAt': _dateToTimestamp(verifiedAt),
      'lastCheckedAt': _dateToTimestamp(lastCheckedAt),
      'confidenceLevel': confidenceLevel,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static Timestamp? _dateToTimestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }
}

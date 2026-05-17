import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRouteCorrectionReport {
  final String id;
  final String routeId;
  final String routeName;
  final String terminalName;
  final String destination;
  final String correctionNote;
  final String submittedByUid;
  final DateTime? submittedAt;

  const AdminRouteCorrectionReport({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.terminalName,
    required this.destination,
    required this.correctionNote,
    required this.submittedByUid,
    required this.submittedAt,
  });

  factory AdminRouteCorrectionReport.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminRouteCorrectionReport(
      id: doc.id,
      routeId: _readString(data['routeId']),
      routeName: _readString(data['routeName']),
      terminalName: _readString(data['terminalName']),
      destination: _readString(data['destination']),
      correctionNote: _readString(data['correctionNote']),
      submittedByUid: _readString(data['submittedByUid']),
      submittedAt: _timestampToDate(data['submittedAt']),
    );
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_route_correction_report.dart';

class AdminRouteCorrectionReportService {
  final FirebaseFirestore _firestore;

  AdminRouteCorrectionReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('route_correction_reports');

  Stream<List<AdminRouteCorrectionReport>> streamAll() {
    return _collection.orderBy('submittedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map(AdminRouteCorrectionReport.fromSnapshot)
              .toList(growable: false),
        );
  }
}

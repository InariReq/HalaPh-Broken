import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:halaph/repositories/backend_repository.dart';

class SharePlanScreen extends StatefulWidget {
  final String planId;
  const SharePlanScreen({Key? key, required this.planId}) : super(key: key);

  @override
  State<SharePlanScreen> createState() => _SharePlanScreenState();
}

class _SharePlanScreenState extends State<SharePlanScreen> {
  Future<String>? _shareLinkFuture;

  @override
  void initState() {
    super.initState();
    _shareLinkFuture = _loadShareLink(widget.planId);
  }

  Future<String> _loadShareLink(String planId) async {
    final repo = BackendRepository();
    final link = await repo.sharePlan(planId);
    return link;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _shareLinkFuture,
      builder: (context, snapshot) {
        final shareUrl = snapshot.data ?? '';
        final display = shareUrl.isNotEmpty ? shareUrl : 'Generating share link...';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Share Plan'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share your plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Text('Plan Link: $display', style: TextStyle(color: Colors.grey[700])),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: shareUrl.isNotEmpty ? () => Share.share(shareUrl) : null,
                  icon: Icon(Icons.share),
                  label: Text('Share Link'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

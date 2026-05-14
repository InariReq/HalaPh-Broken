import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sponsored_ad.dart';

Future<void> openSponsoredAdTargetUrl(SponsoredAd ad) async {
  final rawUrl = ad.targetUrl.trim();

  if (rawUrl.isEmpty) {
    debugPrint('Sponsored ad target URL missing: ${ad.id}');
    return;
  }

  final parsed = Uri.tryParse(rawUrl);
  final uri = parsed != null && parsed.hasScheme
      ? parsed
      : Uri.tryParse('https://$rawUrl');

  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    debugPrint('Sponsored ad target URL failed: ${ad.id} invalid=$rawUrl');
    return;
  }

  debugPrint('Sponsored ad learn more tapped: ${ad.id} -> $uri');

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (opened) {
      debugPrint('Sponsored ad target URL opened: ${ad.id}');
    } else {
      debugPrint('Sponsored ad target URL failed: ${ad.id}');
    }
  } catch (error) {
    debugPrint('Sponsored ad target URL failed: ${ad.id} error=$error');
  }
}

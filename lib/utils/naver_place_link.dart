import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Search handoff while the native Naver SDK and place IDs are being prepared.
Uri naverPlaceSearchUri(String query) => Uri(
  scheme: 'https',
  host: 'map.naver.com',
  pathSegments: ['p', 'search', query.trim()],
);

Future<void> openNaverPlaceSearch(BuildContext context, String query) async {
  if (query.trim().isEmpty) return;
  try {
    if (await launchUrl(
      naverPlaceSearchUri(query),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Show the same actionable message for unsupported URLs and launch failures.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('네이버 지도를 열지 못했습니다. 다시 시도해 주세요.')),
    );
  }
}

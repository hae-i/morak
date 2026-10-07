import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class NaverMapRuntime {
  static final ready = ValueNotifier<bool>(false);
  static Future<void>? _pending;

  static Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final clientId = dotenv.isInitialized
        ? dotenv.env['NAVER_MAP_CLIENT_ID']?.trim()
        : null;
    if (clientId == null || clientId.isEmpty) return;
    if (_pending != null) return _pending;
    _pending = _initialize(clientId);
    try {
      await _pending;
    } finally {
      _pending = null;
    }
  }

  static Future<void> _initialize(String clientId) async {
    var authFailed = false;
    try {
      await FlutterNaverMap()
          .init(
            clientId: clientId,
            onAuthFailed: (_) {
              authFailed = true;
              ready.value = false;
            },
          )
          .timeout(const Duration(seconds: 8));
      ready.value = !authFailed;
    } catch (_) {
      ready.value = false;
      debugPrint('지도를 초기화하지 못했습니다.');
    }
  }
}

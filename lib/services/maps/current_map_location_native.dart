import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../models/place_map_center.dart';

/// A single foreground fix; never subscribes to location tracking.
Future<PlaceMapCenter?> currentMapLocation() async {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  final tracker = NDefaultMyLocationTracker();
  try {
    final granted = Platform.isAndroid
        ? await const MethodChannel('morak/location_permission')
                  .invokeMethod<bool>('requestForegroundLocation') ==
              true
        : await tracker.requestLocationPermission() ==
              NDefaultMyLocationTrackerPermissionStatus.granted;
    if (!granted) return null;
    final point = await tracker.getCurrentPositionOnce().timeout(
      const Duration(seconds: 8),
    );
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return null;
    }
    return PlaceMapCenter(point.latitude, point.longitude);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  } on TimeoutException {
    return null;
  } finally {
    tracker.disposeLocationService();
  }
}

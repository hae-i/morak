import 'package:flutter/material.dart';

import '../../models/meetup_place.dart';
import '../../models/place_map_center.dart';
import 'map_unavailable.dart';

class PlacesMap extends StatelessWidget {
  final List<PlacePin> pins;
  final PlaceMapCenter? initialCenter;
  final ValueChanged<PlaceMapCenter>? onCameraIdle;
  final ValueChanged<PlacePin>? onPinTap;
  final void Function(double latitude, double longitude)? onLongPress;
  const PlacesMap({
    super.key,
    required this.pins,
    this.initialCenter,
    this.onCameraIdle,
    this.onPinTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) => const MapUnavailable();
}

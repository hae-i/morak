import 'package:flutter/material.dart';

import '../../models/meetup_place.dart';
import '../../models/place_map_center.dart';
import 'places_map.dart';

class ExpandablePlacesMap extends StatelessWidget {
  final List<PlacePin> pins;
  final VoidCallback onExpand;
  final PlaceMapCenter? initialCenter;
  final ValueChanged<PlaceMapCenter>? onCameraIdle;
  final ValueChanged<PlacePin>? onPinTap;
  final void Function(double, double)? onLongPress;
  const ExpandablePlacesMap({
    super.key,
    required this.pins,
    required this.onExpand,
    this.initialCenter,
    this.onCameraIdle,
    this.onPinTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      PlacesMap(
        pins: pins,
        initialCenter: initialCenter,
        onCameraIdle: onCameraIdle,
        onPinTap: onPinTap,
        onLongPress: onLongPress,
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          child: IconButton(
            tooltip: '지도 전체 화면으로 보기',
            icon: const Icon(Icons.open_in_full_rounded),
            onPressed: onExpand,
          ),
        ),
      ),
    ],
  );
}

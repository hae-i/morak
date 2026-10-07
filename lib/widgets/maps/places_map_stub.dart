import 'package:flutter/material.dart';

import '../../models/meetup_place.dart';
import 'map_unavailable.dart';

class PlacesMap extends StatelessWidget {
  final List<PlacePin> pins;
  final ValueChanged<PlacePin>? onPinTap;
  final void Function(double latitude, double longitude)? onLongPress;
  const PlacesMap({
    super.key,
    required this.pins,
    this.onPinTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) => const MapUnavailable();
}

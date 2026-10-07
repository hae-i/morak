import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../models/meetup_place.dart';
import '../../services/maps/naver_map_runtime.dart';
import 'map_unavailable.dart';

class PlacesMap extends StatefulWidget {
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
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  NaverMapController? _controller;
  Future<void> _updates = Future.value();
  int _generation = 0;
  bool _failed = false;

  String _signature(List<PlacePin> pins) =>
      pins.map((pin) => '${pin.place.coordinateKey}:${pin.label}').join('|');

  @override
  void didUpdateWidget(PlacesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.pins) != _signature(widget.pins)) _updatePins();
  }

  void _updatePins() {
    final controller = _controller;
    if (controller == null) return;
    final generation = ++_generation;
    final pins = List<PlacePin>.of(widget.pins);
    // Serialize native operations so a stale completion cannot add old pins.
    _updates = _updates
        .then((_) async {
          if (!mounted || generation != _generation) return;
          await controller.clearOverlays(type: NOverlayType.marker);
          if (!mounted || generation != _generation) return;
          final markers = <NMarker>{};
          for (var i = 0; i < pins.length; i++) {
            final pin = pins[i];
            final marker = NMarker(
              id: 'place-$i',
              position: NLatLng(pin.place.latitude, pin.place.longitude),
              caption: NOverlayCaption(text: pin.label),
            );
            marker.setOnTapListener((_) {
              if (mounted && generation == _generation) {
                widget.onPinTap?.call(pin);
              }
            });
            markers.add(marker);
          }
          if (markers.isNotEmpty) await controller.addOverlayAll(markers);
          if (!mounted || generation != _generation) return;
          final bounds = PlaceBounds.fromPlaces(pins.map((pin) => pin.place));
          if (bounds == null) return;
          final update = bounds.isPoint
              ? NCameraUpdate.scrollAndZoomTo(
                  target: NLatLng(bounds.south, bounds.west),
                  zoom: 15,
                )
              : NCameraUpdate.fitBounds(
                  NLatLngBounds(
                    southWest: NLatLng(bounds.south, bounds.west),
                    northEast: NLatLng(bounds.north, bounds.east),
                  ),
                  padding: const EdgeInsets.all(40),
                );
          await controller.updateCamera(update);
        })
        .catchError((Object _) {
          if (mounted && generation == _generation) {
            setState(() => _failed = true);
          }
        });
  }

  @override
  void dispose() {
    _generation++;
    // NaverMap owns and disposes the native controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: NaverMapRuntime.ready,
    builder: (context, ready, _) {
      if (!ready || _failed) return const MapUnavailable();
      final first = widget.pins.firstOrNull?.place;
      return NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: first == null
                ? const NLatLng(37.5666, 126.979)
                : NLatLng(first.latitude, first.longitude),
            zoom: 15,
          ),
          locationButtonEnable: false,
          consumeSymbolTapEvents: false,
        ),
        forceGesture: true,
        onMapReady: (controller) {
          if (!mounted) return;
          _controller = controller;
          _updatePins();
        },
        onMapLongTapped: widget.onLongPress == null
            ? null
            : (_, point) =>
                  widget.onLongPress?.call(point.latitude, point.longitude),
      );
    },
  );
}

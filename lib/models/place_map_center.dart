class PlaceMapCenter {
  final double latitude;
  final double longitude;
  final double zoom;
  const PlaceMapCenter(this.latitude, this.longitude, {this.zoom = 15});

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

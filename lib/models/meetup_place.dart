/// WGS84 coordinates paired with the selected place, never inferred from its name.
class MeetupPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String source;

  MeetupPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.source,
  }) {
    if (name.trim().isEmpty ||
        name.length > 200 ||
        address.length > 500 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        !['naver_search', 'manual_pin'].contains(source)) {
      throw const FormatException('Invalid place');
    }
  }

  factory MeetupPlace.fromJson(Map<String, dynamic> json) {
    if (json['name'] is! String ||
        json['address'] is! String ||
        json['latitude'] is! num ||
        json['longitude'] is! num ||
        json['source'] is! String) {
      throw const FormatException('Invalid place response');
    }
    return MeetupPlace(
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'source': source,
  };

  String get coordinateKey =>
      '${latitude.toStringAsFixed(6)}:${longitude.toStringAsFixed(6)}';

  /// Preserve the province/city to avoid mixing identically named districts.
  /// This is an address classification, not an official administrative code.
  String? get district {
    final tokens = address.trim().split(RegExp(r'\s+'));
    if (tokens.length < 2) return null;
    const provinces = {
      '서울': '서울특별시',
      '서울시': '서울특별시',
      '서울특별시': '서울특별시',
      '부산': '부산광역시',
      '부산광역시': '부산광역시',
      '대구': '대구광역시',
      '대구광역시': '대구광역시',
      '인천': '인천광역시',
      '인천광역시': '인천광역시',
      '광주': '광주광역시',
      '광주광역시': '광주광역시',
      '대전': '대전광역시',
      '대전광역시': '대전광역시',
      '울산': '울산광역시',
      '울산광역시': '울산광역시',
      '세종': '세종특별자치시',
      '세종특별자치시': '세종특별자치시',
      '경기': '경기도',
      '경기도': '경기도',
      '강원': '강원특별자치도',
      '강원도': '강원특별자치도',
      '강원특별자치도': '강원특별자치도',
      '충북': '충청북도',
      '충청북도': '충청북도',
      '충남': '충청남도',
      '충청남도': '충청남도',
      '전북': '전북특별자치도',
      '전라북도': '전북특별자치도',
      '전북특별자치도': '전북특별자치도',
      '전남': '전라남도',
      '전라남도': '전라남도',
      '경북': '경상북도',
      '경상북도': '경상북도',
      '경남': '경상남도',
      '경상남도': '경상남도',
      '제주': '제주특별자치도',
      '제주도': '제주특별자치도',
      '제주특별자치도': '제주특별자치도',
    };
    final province = provinces[tokens.first];
    if (province == null) return null;
    if (province == '세종특별자치시') return province;
    if (!RegExp(r'^[가-힣]+[시군구]$').hasMatch(tokens[1])) return null;
    final city = tokens[1];
    final subdistrict =
        tokens.length > 2 &&
            city.endsWith('시') &&
            RegExp(r'^[가-힣]+구$').hasMatch(tokens[2])
        ? ' ${tokens[2]}'
        : '';
    return '$province $city$subdistrict';
  }
}

class PlaceVisit {
  final String meetupId;
  final String title;
  final String date;
  final MeetupPlace place;
  const PlaceVisit({
    required this.meetupId,
    required this.title,
    required this.date,
    required this.place,
  });
}

class PlacePin {
  final MeetupPlace place;
  final List<PlaceVisit> visits;
  PlacePin({required this.place, required List<PlaceVisit> visits})
    : visits = List.unmodifiable(visits);
  String get label =>
      visits.isEmpty ? place.name : '${place.name} · ${visits.length}번';
}

class DistrictVisits {
  final String name;
  final int count;
  const DistrictVisits(this.name, this.count);
}

class PlaceHistory {
  final List<PlaceVisit> visits;
  PlaceHistory(Iterable<PlaceVisit> visits)
    : visits = List.unmodifiable(visits);

  List<PlacePin> get pins {
    final grouped = <String, List<PlaceVisit>>{};
    for (final visit in visits) {
      grouped.putIfAbsent(visit.place.coordinateKey, () => []).add(visit);
    }
    return grouped.values
        .map((v) => PlacePin(place: v.first.place, visits: v))
        .toList();
  }

  int get unclassifiedMeetups => visits
      .where((v) => v.place.district == null)
      .map((v) => v.meetupId)
      .toSet()
      .length;

  List<DistrictVisits> get districts {
    final counts = <String, Set<String>>{};
    for (final visit in visits) {
      final district = visit.place.district;
      if (district != null) {
        counts.putIfAbsent(district, () => {}).add(visit.meetupId);
      }
    }
    return counts.entries
        .map((e) => DistrictVisits(e.key, e.value.length))
        .toList()
      ..sort((a, b) {
        final result = b.count.compareTo(a.count);
        return result != 0 ? result : a.name.compareTo(b.name);
      });
  }
}

class PlaceBounds {
  final double south, west, north, east;
  const PlaceBounds(this.south, this.west, this.north, this.east);
  bool get isPoint => south == north && west == east;
  static PlaceBounds? fromPlaces(Iterable<MeetupPlace> places) {
    final values = places.toList();
    if (values.isEmpty) return null;
    var south = values.first.latitude, north = south;
    var west = values.first.longitude, east = west;
    for (final place in values.skip(1)) {
      if (place.latitude < south) south = place.latitude;
      if (place.latitude > north) north = place.latitude;
      if (place.longitude < west) west = place.longitude;
      if (place.longitude > east) east = place.longitude;
    }
    return PlaceBounds(south, west, north, east);
  }
}

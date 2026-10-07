import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/meetup_place.dart';

MeetupPlace place(String address, {double lat = 37.5, double lon = 127}) =>
    MeetupPlace(
      name: '카페',
      address: address,
      latitude: lat,
      longitude: lon,
      source: 'naver_search',
    );
PlaceVisit visit(String id, MeetupPlace p) =>
    PlaceVisit(meetupId: id, title: id, date: '2026-10-07', place: p);

void main() {
  test('invalid or non-finite coordinates never become map pins', () {
    for (final invalid in [double.nan, double.infinity, 91.0, -91.0]) {
      expect(() => place('서울 송파구', lat: invalid), throwsFormatException);
    }
    expect(() => place('서울 송파구', lon: 181), throwsFormatException);
    expect(
      () => MeetupPlace.fromJson({
        'name': '카페',
        'address': '',
        'latitude': '37.5',
        'longitude': 127,
        'source': 'naver_search',
      }),
      throwsFormatException,
    );
  });

  test('districts normalize province names and preserve city/subdistrict', () {
    expect(place('서울 송파구 잠실동').district, '서울특별시 송파구');
    expect(place('서울특별시 송파구 올림픽로 10').district, '서울특별시 송파구');
    expect(place('경기도 성남시 분당구 정자동').district, '경기도 성남시 분당구');
    expect(place('부산광역시 중구 중앙동').district, '부산광역시 중구');
    expect(place('서울특별시 중구 을지로').district, '서울특별시 중구');
    expect(place('임의 장소 송파구').district, isNull);
    expect(place('').district, isNull);
  });

  test('regional count deduplicates a meetup and keeps homonymous regions separate', () {
    final history = PlaceHistory([
      visit('one', place('서울 송파구 잠실동')),
      visit('one', place('서울특별시 송파구 석촌동', lat: 37.51)),
      visit('two', place('서울특별시 송파구 올림픽로')),
      visit('three', place('서울특별시 중구 을지로')),
      visit('four', place('부산광역시 중구 중앙동')),
      visit('unknown', place('')),
    ]);
    expect(history.districts.first.name, '서울특별시 송파구');
    expect(history.districts.first.count, 2);
    expect(history.districts.length, 3);
    expect(history.unclassifiedMeetups, 1);
  });

  test('repeated location has one pin while keeping every visit', () {
    final p = place('서울 송파구');
    final history = PlaceHistory([visit('one', p), visit('two', p)]);
    expect(history.pins.length, 1);
    expect(history.pins.single.visits.map((v) => v.meetupId), ['one', 'two']);
  });

  test('bounds include all pins and handle no pins / one location', () {
    expect(PlaceBounds.fromPlaces([]), isNull);
    expect(PlaceBounds.fromPlaces([place('')])!.isPoint, isTrue);
    final bounds = PlaceBounds.fromPlaces([
      place('', lat: 37.7, lon: 127.3),
      place('', lat: 37.1, lon: 126.8),
    ])!;
    expect(
      [bounds.south, bounds.west, bounds.north, bounds.east],
      [37.1, 126.8, 37.7, 127.3],
    );
    expect(bounds.isPoint, isFalse);
  });
}

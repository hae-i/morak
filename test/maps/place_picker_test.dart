import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/meetup_place.dart';
import 'package:morak/models/place_map_center.dart';
import 'package:morak/repositories/place_search_repository.dart';
import 'package:morak/screens/group/place_picker_screen.dart';
import 'package:morak/widgets/common/common_button.dart';
import 'package:morak/widgets/maps/places_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

MeetupPlace candidate(String name) => MeetupPlace(
  name: name,
  address: '서울특별시 송파구 올림픽로 10',
  latitude: 37.5,
  longitude: 127.1,
  source: 'naver_search',
);

class _Search extends PlaceSearchRepository {
  _Search()
    : super(
        client: SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  bool controlledReverse = false;
  final reverseRequests = <Completer<MeetupPlace>>[];
  @override
  Future<MeetupPlace> reverseGeocode({
    required String groupId,
    required PlaceMapCenter center,
  }) {
    if (!controlledReverse) {
      return Future.error(const PlaceSearchException('주소를 가져오지 못했어요.'));
    }
    final request = Completer<MeetupPlace>();
    reverseRequests.add(request);
    return request.future;
  }

  final requests = <Completer<List<MeetupPlace>>>[];
  final queries = <String>[];
  final centers = <PlaceMapCenter?>[];
  @override
  Future<List<MeetupPlace>> search({
    required String groupId,
    required String query,
    String mode = 'place',
    PlaceMapCenter? center,
  }) {
    queries.add(query);
    centers.add(center);
    final pending = Completer<List<MeetupPlace>>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  testWidgets('late searches cannot replace results for the current query', (
    tester,
  ) async {
    final repository = _Search();
    await tester.pumpWidget(
      MaterialApp(
        home: PlacePickerScreen(
          groupId: 'group',
          repository: repository,
          fullScreen: true,
          initialCenter: const PlaceMapCenter(37.5, 127.1),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'old');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump();
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    repository.requests[1].complete([candidate('새 장소')]);
    await tester.pumpAndSettle();
    repository.requests[0].complete([candidate('이전 장소')]);
    await tester.pumpAndSettle();
    expect(find.text('새 장소'), findsOneWidget);
    expect(find.text('이전 장소'), findsNothing);
    await tester.ensureVisible(find.text('새 장소'));
    await tester.tap(find.text('새 장소'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Button>(find.widgetWithText(Button, '이 장소 선택하기')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failure is retryable and a disposed search never updates its screen',
    (tester) async {
      final repository = _Search();
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            fullScreen: true,
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '카페');
      await tester.tap(find.byTooltip('검색'));
      await tester.pump();
      repository.requests.single.completeError(
        StateError('private provider details'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private provider'), findsNothing);
      await tester.ensureVisible(find.widgetWithText(Button, '검색 다시 시도'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, '검색 다시 시도'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      repository.requests.last.complete([candidate('늦은 장소')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an existing place can be confirmed without another search', (
    tester,
  ) async {
    final original = candidate('기존 장소');
    final repository = _Search();
    MeetupPlace? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => selected = await Navigator.push<MeetupPlace>(
              context,
              MaterialPageRoute(
                builder: (_) => PlacePickerScreen(
                  groupId: 'group',
                  repository: repository,
                  initialPlace: original,
                  initialCenter: const PlaceMapCenter(37.5, 127.1),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, '이 장소 선택하기'));
    await tester.pumpAndSettle();
    expect(identical(selected, original), isTrue);
    expect(repository.requests, isEmpty);
  });
  testWidgets(
    'typing is debounced and uses the map center without dismissing the keyboard',
    (tester) async {
      final repository = _Search();
      const center = PlaceMapCenter(37.5, 127.1);
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            fullScreen: true,
            initialCenter: center,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '카페');
      await tester.pump(const Duration(milliseconds: 600));
      expect(repository.requests, isEmpty);
      await tester.enterText(find.byType(TextField), '카페 모락');
      await tester.pump(const Duration(milliseconds: 700));
      expect(repository.queries, ['카페 모락']);
      expect(identical(repository.centers.single, center), isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus ??
            FocusManager.instance.primaryFocus?.hasFocus,
        isTrue,
      );
      repository.requests.single.complete([candidate('모락 카페')]);
      await tester.pumpAndSettle();
      expect(find.text('모락 카페'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen keeps candidates and confirms the selection back to the record',
    (tester) async {
      final repository = _Search();
      final original = candidate('기존 장소');
      MeetupPlace? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  selected = await Navigator.push<MeetupPlace>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlacePickerScreen(
                        groupId: 'group',
                        repository: repository,
                        initialQuery: '기존',
                        initialResults: [original],
                        initialMode: 'address',
                        initialCenter: const PlaceMapCenter(37.5, 127.1),
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final screen = tester.widget<PlacePickerScreen>(
        find.byType(PlacePickerScreen).last,
      );
      expect(screen.fullScreen, isTrue);
      expect(screen.initialMode, 'address');
      expect(find.text('기존 장소'), findsOneWidget);
      await tester.tap(find.text('기존 장소'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, '이 장소 선택하기').last);
      await tester.pumpAndSettle();
      expect(identical(selected, original), isTrue);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fullscreen remains usable on a small screen with larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: PlacePickerScreen(
          groupId: 'group',
          repository: _Search(),
          fullScreen: true,
          initialPlace: candidate('기존 장소'),
          initialCenter: const PlaceMapCenter(37.5, 127.1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이 장소 선택하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'map fills the screen under a transparent header and square icon search',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'AppFont'),
          home: PlacePickerScreen(
            groupId: 'group',
            repository: _Search(),
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('지도 주변'), findsNothing);
      expect(find.text('전체 지역'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      final map = tester.getRect(find.byType(PlacesMap));
      final scaffold = tester.getRect(find.byType(Scaffold));
      expect(map, scaffold);
      expect(find.text('만난 장소 찾기'), findsNothing);
      expect(find.text('장소 검색하기'), findsOneWidget);
      expect(find.text('검색하거나 지도를 길게 눌러 장소를 선택해 주세요'), findsOneWidget);
      final button = tester.getSize(find.byTooltip('검색'));
      expect(button.width, 48);
      expect(button.height, 48);
      expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.turn_right_rounded),
          matching: find.byType(Button),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.fillColor,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manual pin clears on user movement while automatic camera positioning keeps it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: _Search(),
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onLongPress!(
        37.5,
        127.1,
      );
      await tester.pumpAndSettle();
      expect(find.text('직접 선택한 장소'), findsOneWidget);
      expect(
        tester.widget<PlacesMap>(find.byType(PlacesMap)).pins,
        hasLength(1),
      );
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onCameraIdle!(
        const PlaceMapCenter(37.5, 127.1),
      );
      await tester.pump();
      expect(find.text('직접 선택한 장소'), findsOneWidget);
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onUserMove!();
      await tester.pumpAndSettle();
      expect(find.text('직접 선택한 장소'), findsNothing);
      expect(tester.widget<PlacesMap>(find.byType(PlacesMap)).pins, isEmpty);
      expect(
        tester
            .widget<Button>(find.widgetWithText(Button, '이 장소 선택하기'))
            .onPressed,
        isNull,
      );
      expect(tester.getSize(find.byTooltip('뒤로')).width, 32);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('moving the map keeps a searched place selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlacePickerScreen(
          groupId: 'group',
          repository: _Search(),
          initialPlace: candidate('검색한 장소'),
          initialCenter: const PlaceMapCenter(37.5, 127.1),
        ),
      ),
    );
    tester.widget<PlacesMap>(find.byType(PlacesMap)).onUserMove!();
    await tester.pumpAndSettle();
    expect(find.text('검색한 장소'), findsOneWidget);
    expect(tester.widget<PlacesMap>(find.byType(PlacesMap)).pins, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    're-search follows the live camera and hides only after a successful request',
    (tester) async {
      final repository = _Search();
      const first = PlaceMapCenter(37.5, 127.1);
      var current = first;
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            initialCenter: first,
          ),
        ),
      );
      PlacesMap map() => tester.widget<PlacesMap>(find.byType(PlacesMap));
      map().onCenterReaderReady!(() async => current);
      map().onUserMove!();
      await tester.pump();
      expect(find.text('현재 위치에서 다시 검색'), findsNothing);
      await tester.enterText(find.byType(TextField), '스타벅스');
      await tester.tap(find.byTooltip('검색'));
      await tester.pump();
      repository.requests.single.complete([candidate('스타벅스 잠실점')]);
      await tester.pumpAndSettle();
      expect(repository.centers.single, first);
      expect(map().fitPins, isFalse);
      // Programmatic camera events must not mark the view as moved.
      map().onCameraIdle!(first);
      await tester.pump();
      expect(find.text('현재 위치에서 다시 검색'), findsNothing);
      current = const PlaceMapCenter(35.16, 129.16);
      map().onUserMove!();
      await tester.pump();
      expect(repository.requests, hasLength(1));
      await tester.tap(find.text('현재 위치에서 다시 검색'));
      await tester.pump();
      expect(repository.centers.last, current);
      repository.requests.last.completeError(
        const PlaceSearchException('검색 오류'),
      );
      await tester.pumpAndSettle();
      expect(find.text('현재 위치에서 다시 검색'), findsOneWidget);
      await tester.tap(find.text('현재 위치에서 다시 검색'));
      await tester.pump();
      repository.requests.last.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('현재 위치에서 다시 검색'), findsNothing);
      map().onUserMove!();
      await tester.pump();
      expect(find.text('현재 위치에서 다시 검색'), findsOneWidget);
    },
  );

  testWidgets(
    'moving while a search is pending keeps the re-search action visible',
    (tester) async {
      final repository = _Search();
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '카페');
      await tester.tap(find.byTooltip('검색'));
      await tester.pump();
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onUserMove!();
      repository.requests.single.complete([candidate('카페')]);
      await tester.pumpAndSettle();
      expect(find.text('현재 위치에서 다시 검색'), findsOneWidget);
    },
  );

  testWidgets('a location fix initializes the map without starting a search', (
    tester,
  ) async {
    final repository = _Search();
    final location = Completer<PlaceMapCenter?>();
    await tester.pumpWidget(
      MaterialApp(
        home: PlacePickerScreen(
          groupId: 'group',
          repository: repository,
          locationLoader: () => location.future,
        ),
      ),
    );
    const position = PlaceMapCenter(35.16, 129.16);
    location.complete(position);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlacesMap>(find.byType(PlacesMap)).initialCenter,
      position,
    );
    expect(repository.requests, isEmpty);
    expect(find.text('현재 위치에서 다시 검색'), findsNothing);
  });

  testWidgets('a late location fix does not undo a user moving the map', (
    tester,
  ) async {
    final repository = _Search();
    final location = Completer<PlaceMapCenter?>();
    await tester.pumpWidget(
      MaterialApp(
        home: PlacePickerScreen(
          groupId: 'group',
          repository: repository,
          locationLoader: () => location.future,
        ),
      ),
    );
    final map = tester.widget<PlacesMap>(find.byType(PlacesMap));
    map.onUserMove!();
    const viewed = PlaceMapCenter(37.5, 127.1);
    map.onCameraIdle!(viewed);
    location.complete(const PlaceMapCenter(35.16, 129.16));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlacesMap>(find.byType(PlacesMap)).initialCenter,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '카페');
    await tester.tap(find.byTooltip('검색'));
    await tester.pump();
    expect(repository.centers.single, viewed);
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'renaming an address result preserves its address and coordinates on confirmation',
    (tester) async {
      final repository = _Search();
      final address = MeetupPlace(
        name: '서울 송파구 올림픽로 10',
        address: '서울 송파구 올림픽로 10',
        latitude: 37.5,
        longitude: 127.1,
        source: 'naver_geocode',
      );
      MeetupPlace? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  selected = await Navigator.push<MeetupPlace>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlacePickerScreen(
                        groupId: 'group',
                        repository: repository,
                        initialPlace: address,
                        initialCenter: const PlaceMapCenter(37.5, 127.1),
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final nameField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '장소 이름',
      );
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, '우리 아지트');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      tester
          .widget<Button>(find.widgetWithText(Button, '이 장소 선택하기'))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(selected!.name, '우리 아지트');
      expect(selected!.address, address.address);
      expect(selected!.coordinateKey, address.coordinateKey);
      expect(selected!.source, 'naver_geocode');
    },
  );

  testWidgets(
    'a late pin address preserves an edited name and cannot restore a cleared pin',
    (tester) async {
      final repository = _Search()..controlledReverse = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onLongPress!(
        37.5,
        127.1,
      );
      await tester.pump();
      final nameField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '장소 이름',
      );
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, '친구 집');
      repository.reverseRequests.single.complete(
        MeetupPlace(
          name: '직접 선택한 장소',
          address: '서울 송파구 올림픽로 10',
          latitude: 37.5,
          longitude: 127.1,
          source: 'manual_pin',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(nameField).controller!.text, '친구 집');
      expect(
        tester
            .widget<PlacesMap>(find.byType(PlacesMap))
            .pins
            .single
            .place
            .address,
        '서울 송파구 올림픽로 10',
      );
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onLongPress!(
        37.6,
        127.2,
      );
      await tester.pump();
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onUserMove!();
      repository.reverseRequests.last.complete(
        MeetupPlace(
          name: '직접 선택한 장소',
          address: '늦게 도착한 주소',
          latitude: 37.6,
          longitude: 127.2,
          source: 'manual_pin',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<PlacesMap>(find.byType(PlacesMap)).pins, isEmpty);
      expect(find.text('늦게 도착한 주소'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmation is visibly disabled until a result or pin is selected',
    (tester) async {
      final repository = _Search();
      await tester.pumpWidget(
        MaterialApp(
          home: PlacePickerScreen(
            groupId: 'group',
            repository: repository,
            initialCenter: const PlaceMapCenter(37.5, 127.1),
          ),
        ),
      );
      ElevatedButton confirm() => tester.widget<ElevatedButton>(
        find.descendant(
          of: find.widgetWithText(Button, '이 장소 선택하기'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(confirm().onPressed, isNull);
      final disabledColor = confirm().style!.backgroundColor!.resolve({
        WidgetState.disabled,
      });
      await tester.enterText(find.byType(TextField), '카페');
      await tester.tap(find.byTooltip('검색'));
      await tester.pump();
      repository.requests.single.complete([candidate('카페')]);
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNull);
      await tester.tap(find.text('카페').last);
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNotNull);
      expect(
        confirm().style!.backgroundColor!.resolve({}),
        isNot(disabledColor),
      );
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '장소 검색하기',
      );
      await tester.enterText(searchField, '다른 카페');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      tester.widget<PlacesMap>(find.byType(PlacesMap)).onLongPress!(
        37.5,
        127.1,
      );
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNotNull);
    },
  );
}

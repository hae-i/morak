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
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'old');
    await tester.tap(find.widgetWithText(Button, '검색'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, '검색'));
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
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '카페');
      await tester.tap(find.widgetWithText(Button, '검색'));
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이 장소 선택하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'map fills the screen under compact search controls and inherits the app font',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'AppFont'),
          home: PlacePickerScreen(groupId: 'group', repository: _Search()),
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
      expect(
        tester.widget<Button>(find.widgetWithText(Button, '검색')).height,
        40,
      );
      expect(
        tester.widget<Text>(find.text('만난 장소 찾기')).style?.fontFamily,
        'AppFont',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

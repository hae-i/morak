import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/meetup_place.dart';
import 'package:morak/repositories/place_search_repository.dart';
import 'package:morak/screens/group/place_picker_screen.dart';
import 'package:morak/widgets/common/common_button.dart';
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
  @override
  Future<List<MeetupPlace>> search({
    required String groupId,
    required String query,
  }) {
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
        home: PlacePickerScreen(groupId: 'group', repository: repository),
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
          home: PlacePickerScreen(groupId: 'group', repository: repository),
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
}

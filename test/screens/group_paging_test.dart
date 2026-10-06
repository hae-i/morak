import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/screens/group/group_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 늦은 페이지·새로고침 경합·재시도·dispose를 실제 상세 화면에서 검증한다 ===
void main() {
  testWidgets('refresh discards late pages and failed pages can retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:1',
      publishableKey: 'test-public-key',
      debug: false,
      httpClient: MockClient((_) async => http.Response('', 204)),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
      ),
    );
    final repo = _Groups();
    locator.registerSingleton<GroupRepository>(repo);
    addTearDown(() => locator.reset());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(home: GroupDetailScreen(groupId: 'g')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진첩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 더 불러오기'));
    await tester.pump();
    expect(repo.pageCalls, 1);
    // 스크롤/중복 요청이 겹쳐도 진행 중인 페이지 요청은 하나입니다.
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
    repo.pending.complete([record('old')]);
    await tester.pumpAndSettle();
    expect(repo.pageCalls, 1);
    repo.fail = true;
    await tester.tap(find.text('기록 더 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('기록 조회 다시 시도'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('기록 조회 다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.offsets, [1, 1, 1]);
    expect(find.text('기록 더 불러오기'), findsNothing);
    await tester.tap(find.widgetWithText(Tab, '만남 기록'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsNothing);
    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('next'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 폐기된 화면에 완료된 페이지 응답을 적용하지 않습니다.
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진첩'));
    await tester.pumpAndSettle();
    repo.delayed = true;
    repo.pending = Completer<List<MeetupModel>>();
    await tester.tap(find.text('기록 더 불러오기'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repo.pending.complete([record('disposed')]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

MeetupModel record(String id) => MeetupModel(
  id: id,
  groupId: 'g',
  title: id,
  date: '2026-10-06',
  photos: [],
  attendanceMemberIds: [],
);

class _Groups extends GroupRepository {
  int summaries = 0;
  int pageCalls = 0;
  bool fail = false;
  bool delayed = false;
  final offsets = <int>[];
  Completer<List<MeetupModel>> pending = Completer<List<MeetupModel>>();
  @override
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(
    String groupId,
  ) async => {
    'group': GroupModel(id: 'g', name: 'Group'),
    'rankedMembers': <MemberModel>[],
    'meetups': [record(++summaries == 1 ? 'initial' : 'fresh')],
    'totalMeetups': 2,
    'paged': true,
  };
  @override
  Future<List<MeetupModel>> fetchMeetupPage(
    String groupId, {
    int offset = 0,
    int limit = 40,
  }) async {
    offsets.add(offset);
    if (++pageCalls == 1 || delayed) return pending.future;
    if (fail) throw StateError('private failure');
    return [record('next')];
  }
}

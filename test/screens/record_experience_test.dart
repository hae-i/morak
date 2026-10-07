import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/screens/auth/login_screen.dart';
import 'package:morak/utils/naver_place_link.dart';
import 'package:morak/widgets/group/group_attendance_summary.dart';
import 'package:morak/widgets/meetup/meetup_story.dart';

MemberModel member(String id, {bool deleted = false, int count = 0}) =>
    MemberModel(
      id: id,
      userId: id,
      displayName: 'name-$id',
      role: 'member',
      isDeleted: deleted,
      isBirthdayPublic: false,
      attendedCount: count,
    );

void main() {
  testWidgets('intro stays scrollable on a short screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Google로 시작하기'), findsOneWidget);
    for (var index = 1; index <= 4; index++) {
      await tester.tap(find.byTooltip('$index번째 소개'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'story preserves unknown attendees and anonymizes departed names',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MeetupStory(
                meetup: MeetupModel(
                  id: 'record',
                  groupId: 'group',
                  title: 'Birthday',
                  date: '2026-10-07',
                  location: '연남동',
                  menu: '케이크',
                  photos: [],
                  attendanceMemberIds: [
                    'active',
                    'deleted',
                    'unknown',
                    'unknown',
                  ],
                ),
                members: [member('active'), member('deleted', deleted: true)],
                onOpenPhotos: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('3명이 함께한 만남'), findsOneWidget);
      expect(find.text('이전 참석 기록 1명'), findsOneWidget);
      expect(find.text('탈퇴한 멤버'), findsOneWidget);
      expect(find.text('name-deleted'), findsNothing);
      expect(find.text('연남동'), findsOneWidget);
      expect(find.text('케이크'), findsOneWidget);
      expect(find.text('네이버 지도에서 장소 찾기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'attendance uses entire group count and excludes departed members',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAttendanceSummary(
              members: [
                member('active', count: 3),
                member('deleted', deleted: true, count: 10),
              ],
              totalMeetups: 10,
              onRefresh: () async {},
            ),
          ),
        ),
      );
      expect(find.text('만남 10번 · 현재 멤버 1명'), findsOneWidget);
      expect(find.text('전체 10번 중 3번 함께했어요 · 30%'), findsOneWidget);
      expect(find.text('name-deleted'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty attendance never divides by zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAttendanceSummary(
            members: [member('active')],
            totalMeetups: 0,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('첫 만남을 기록하면 함께한 시간이 여기에 쌓여요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Naver search encodes place names as a path, not query instructions',
    () {
      final uri = naverPlaceSearchUri('  서울 카페 / A&B?x=1  ');
      expect(uri.host, 'map.naver.com');
      expect(uri.query, isEmpty);
      expect(uri.pathSegments, ['p', 'search', '서울 카페 / A&B?x=1']);
    },
  );
}

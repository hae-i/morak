import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:morak/screens/group/meetup_create_screen.dart';
import 'package:morak/widgets/common/common_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 기본 카운터 대신 기록 편집의 데이터 보존과 지연 조회를 검증한다 ===
void main() {
  late _Groups groups;
  late _Meetups meetups;
  setUp(() {
    groups = _Groups();
    meetups = _Meetups();
    locator.registerSingleton<GroupRepository>(groups);
    locator.registerSingleton<MeetupRepository>(meetups);
  });
  tearDown(() => locator.reset());
  Future<void> openEditor(WidgetTester tester) async {
    groups.pending = Completer<List<MemberModel>>();
    await tester.pumpWidget(
      MaterialApp(
        home: MeetupCreateScreen(
          groupId: 'group',
          initialMeetup: MeetupModel(
            id: 'meetup',
            groupId: 'group',
            title: 'Original',
            date: '2026-01-15',
            location: 'Original place',
            menu: 'Original menu',
            photos: [],
            attendanceMemberIds: ['member'],
          ),
        ),
      ),
    );
  }

  testWidgets('delayed members preserve edits and saving waits for members', (
    tester,
  ) async {
    await openEditor(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Original',
    );
    expect(find.text('수정 완료'), findsNothing);
    await tester.enterText(
      find.byType(TextField).first,
      'Edited while loading',
    );
    groups.pending.complete([]);
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Edited while loading',
    );
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.text('수정 완료'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<Button>(find.widgetWithText(Button, '수정 완료')).onPressed!();
    await tester.pump();
    expect(meetups.saves, 1);
    expect(meetups.title, 'Edited while loading');
    expect(meetups.date, startsWith('2026-01-15'));
    expect(meetups.attendees, {'member'});
  });
  testWidgets(
    'failed initialization preserves original; save retries without writing',
    (tester) async {
      await openEditor(tester);
      groups.pending.completeError(StateError('private server error'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('private server error'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Original',
      );
      groups.pending = Completer<List<MemberModel>>();
      await tester.scrollUntilVisible(
        find.text('수정 완료'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      tester.widget<Button>(find.widgetWithText(Button, '수정 완료')).onPressed!();
      await tester.pump();
      expect(meetups.saves, 0);
      expect(groups.calls, 2);
      groups.pending.complete([]);
      await tester.pump();
    },
  );
  testWidgets('late initialization after disposal does not touch controllers', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    groups.pending.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(meetups.saves, 0);
  });
}

SupabaseClient _client() =>
    SupabaseClient('http://localhost:1', 'test-public-key');

class _Groups extends GroupRepository {
  _Groups() : super(client: _client());
  int calls = 0;
  Completer<List<MemberModel>> pending = Completer();
  @override
  Future<List<MemberModel>> fetchGroupMembers(String groupId) {
    calls++;
    return pending.future;
  }
}

class _Meetups extends MeetupRepository {
  _Meetups() : super(client: _client());
  int saves = 0;
  String? title, date;
  Set<String>? attendees;
  @override
  Future<void> saveMeetup({
    required String groupId,
    String? meetupId,
    String? title,
    required String meetDate,
    String? location,
    String? menu,
    required List<dynamic> photos,
    required Set<String> memberIds,
  }) async {
    saves++;
    this.title = title;
    date = meetDate;
    attendees = memberIds;
  }
}

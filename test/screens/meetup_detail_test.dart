import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/models/meetup_place.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:morak/screens/group/meetup_detail_screen.dart';
import 'package:morak/screens/group/photo_viewer_screen.dart';
import 'package:morak/widgets/common/common_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 실제 상세 화면에서 제목, 편집 후 재조회, 삭제 취소와 실패를 검증한다 ===
void main() {
  // === 수정한 내용: 실제 로그인 멤버와 작성자가 일치해야 상세 관리 버튼을 표시하는지 검증한다 ===
  setUpAll(() async {
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
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'user': {
          'id': '00000000-0000-0000-0000-000000000001',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  late _Meetups repo;
  setUp(() {
    repo = _Meetups();
    locator.registerSingleton<MeetupRepository>(repo);
    locator.registerSingleton<GroupRepository>(_Groups());
  });
  tearDown(() => locator.reset());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetupDetailScreen(
                    meetup: record('Saved title'),
                    groupMembers: [actor()],
                    activeColor: Colors.blue,
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String choice) async {
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing refreshes the saved title and preserves existing attendance',
    (tester) async {
      await open(tester);
      expect(find.text('Saved title'), findsOneWidget);
      await menu(tester, '기록 수정하기');
      await tester.enterText(find.byType(TextField).first, 'Updated title');
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('수정 완료'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(Button, '수정 완료'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.reads, 1);
      expect(repo.attendees, {'member'});
      expect(find.text('Updated title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancel keeps the record; confirmed deletion closes detail', (
    tester,
  ) async {
    await open(tester);
    await menu(tester, '기록 삭제하기');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    expect(find.text('Saved title'), findsOneWidget);
    await menu(tester, '기록 삭제하기');
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.byType(MeetupDetailScreen), findsNothing);
  });
  testWidgets('delete failure stays on detail and hides server details', (
    tester,
  ) async {
    repo.failDelete = true;
    await open(tester);
    await menu(tester, '기록 삭제하기');
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('Saved title'), findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
    expect(find.text('기록을 삭제하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
  });
  testWidgets(
    'album entry reads latest record and returns to the original parent',
    (tester) async {
      repo.title = 'Latest album record';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      imageUrls: const [],
                      initialIndex: 0,
                      meetup: record('Old title'),
                      groupMembers: [actor()],
                      activeColor: Colors.blue,
                    ),
                  ),
                ),
                child: const Text('Open album'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pump();
      expect(find.text('갤러리에 사진을 저장했습니다.'), findsNothing);
      expect(find.textContaining('다운로드 완료'), findsNothing);
      await tester.tap(find.text('기록 보러가기'));
      await tester.pumpAndSettle();
      expect(repo.reads, 1);
      expect(find.text('Latest album record'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.text('Open album'), findsOneWidget);
    },
  );
  // === 수정한 내용: 앨범에서 다음 사진으로 이동하면 해당 사진의 기록을 조회하는지 검증한다 ===
  testWidgets('swiping album photos opens the matching record', (tester) async {
    final second = MeetupModel(
      id: 'second',
      groupId: 'group',
      title: 'Second',
      date: '2026-10-06',
      photos: [],
      attendanceMemberIds: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoViewerScreen(
          imageUrls: const [
            'https://example.invalid/a.jpg',
            'https://example.invalid/b.jpg',
          ],
          initialIndex: 0,
          meetup: record('First'),
          photoMeetups: [record('First'), second],
          groupMembers: [actor()],
          activeColor: Colors.blue,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.text('기록 보러가기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.lastRead, 'second');
    expect(tester.takeException(), isNull);
  });
}

MeetupModel record(String title) => MeetupModel(
  id: 'meetup',
  groupId: 'group',
  authorMemberId: 'member',
  authorName: 'Author',
  title: title,
  date: '2026-10-05',
  location: 'Place',
  menu: 'Menu',
  photos: [],
  attendanceMemberIds: ['member'],
);
SupabaseClient client() => SupabaseClient(
  'http://localhost:1',
  'test-public-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _Meetups extends MeetupRepository {
  _Meetups() : super(client: client());
  int saves = 0, reads = 0, deletes = 0;
  bool failDelete = false;
  String title = 'Saved title';
  String? lastRead;
  Set<String>? attendees;
  @override
  Future<MeetupModel> fetchMeetup(String id) async {
    reads++;
    lastRead = id;
    return record(title);
  }

  @override
  Future<void> deleteMeetup(String id) async {
    deletes++;
    if (failDelete) throw StateError('private server detail');
  }

  @override
  Future<void> saveMeetup({
    required String groupId,
    String? meetupId,
    String? title,
    required String meetDate,
    String? location,
    String? menu,
    MeetupPlace? place,
    bool updatePlace = false,
    required List<dynamic> photos,
    required Set<String> memberIds,
  }) async {
    saves++;
    this.title = title!;
    attendees = memberIds;
  }
}

class _Groups extends GroupRepository {
  _Groups() : super(client: client());
  @override
  Future<List<MemberModel>> fetchGroupMembers(String groupId) async => [];
}

MemberModel actor() => MemberModel(
  id: 'member',
  userId: '00000000-0000-0000-0000-000000000001',
  displayName: 'Author',
  role: 'member',
  isBirthdayPublic: false,
);

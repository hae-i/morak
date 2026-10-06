import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/screens/group/group_detail_screen.dart';
import 'package:morak/screens/group/group_info_screen.dart';
import 'package:morak/widgets/group/member_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 넓은 화면 상단바 제거와 좁은 화면 메뉴·공통 설정·공유를 실제 화면에서 검증한다 ===
void main() {
  testWidgets('wide and narrow detail share the same sidebar actions', (
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
    locator.registerSingleton<GroupRepository>(_Groups());
    addTearDown(() => locator.reset());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          clipboard = (call.arguments as Map)['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: GroupDetailScreen(groupId: 'g')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MemberDrawer),
        matching: find.text('Group'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('멤버 관리'), findsNothing);
    expect(find.text('초대링크 복사하기'), findsNothing);
    await tester.tap(find.byTooltip('모임 공유'));
    await tester.pumpAndSettle();
    expect(clipboard, 'https://morak.app/invite?groupId=g');
    // === 수정한 내용: 하단 아이콘을 가리는 공유 완료 안내가 사라진 후 설정을 누른다 ===
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('모임 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupInfoScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.settings_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.share_outlined),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('모임 메뉴'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('모임 설정'), findsOneWidget);
    expect(find.byTooltip('모임 공유'), findsOneWidget);
    await tester.tap(find.byTooltip('모임 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupInfoScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Groups extends GroupRepository {
  @override
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(
    String groupId,
  ) async => {
    'group': GroupModel(id: 'g', name: 'Group'),
    'meetups': <MeetupModel>[],
    'rankedMembers': <MemberModel>[],
  };
}

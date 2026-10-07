import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/user_model.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/screens/main_skeleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === 수정한 내용: 사이드바와 하단 탭의 선택 동기화 및 화면 폭 변경 후 선택 보존을 검증한다 ===
void main() {
  testWidgets('wide menu and mobile tabs share selection', (tester) async {
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
    final groups = _Groups();
    locator.registerSingleton<GroupRepository>(groups);
    locator.registerSingleton<UserRepository>(_Users());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MainSkeleton())),
    );
    await tester.pumpAndSettle();
    // === 수정한 내용: 선택 전후 하단 탭 글자 크기·굵기가 동일하게 유지되는지 확인한다 ===
    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.selectedLabelStyle, nav.unselectedLabelStyle);
    expect(nav.selectedFontSize, nav.unselectedFontSize);
    await tester.tap(find.widgetWithText(ListTile, '내 모임'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    await tester.tap(find.widgetWithText(ListTile, '마이페이지'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
    final bottomHome = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('홈'),
    );
    await tester.tap(bottomHome);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '홈')).selected,
      true,
    );
    await tester.tap(find.widgetWithText(ListTile, '내 모임'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    expect(find.widgetWithText(ListTile, '홈'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await locator.reset();
  });
}

class _Groups extends GroupRepository {
  bool hasCreatedGroup = false;
  @override
  Future<List<Map<String, dynamic>>> fetchMyGroups() async => hasCreatedGroup
      ? [
          {'group': GroupModel(id: 'new', name: 'New group'), 'role': 'host'},
        ]
      : [];
}

class _Users extends UserRepository {
  @override
  Future<UserModel?> fetchMyGlobalProfile() async =>
      UserModel(id: 'user', displayName: 'Name');
}

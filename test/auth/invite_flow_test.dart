import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:morak/main.dart';
import 'package:morak/locator.dart';
import 'package:morak/router.dart';
import 'package:morak/models/user_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:morak/screens/group/group_detail_screen.dart';
import 'package:morak/widgets/group/group_join_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 로그인 전 초대 보존, 공개 여부 전달, 가입 결과와 조회 실패 재시도를 검증한다 ===
void main() {
  testWidgets(
    'invite survives login and returns membership result with privacy selection',
    (tester) async {
      await Supabase.initialize(
        url: 'http://127.0.0.1:1',
        publishableKey: 'test-public-key',
        debug: false,
        httpClient: MockClient((_) async => http.Response('', 204)),
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUri: false,
          pkceAsyncStorage: _Memory(),
        ),
      );
      final groups = _Groups();
      locator.registerSingleton<GroupRepository>(groups);
      locator.registerSingleton<UserRepository>(_Users());
      locator.registerSingleton<MeetupRepository>(_Feeds());
      Future<void> frames() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.pumpWidget(const ProviderScope(child: MorakApp()));
      await frames();
      router.go('/invite?groupId=invited-group');
      await frames();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      await Supabase.instance.client.auth.recoverSession(
        jsonEncode({
          'access_token': 'local-test-token',
          'refresh_token': 'local-test-refresh',
          'token_type': 'bearer',
          'user': {
            'id': '00000000-0000-0000-0000-000000000001',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      await frames();
      expect(router.routeInformationProvider.value.uri.path, '/invite');
      expect(find.byType(GroupJoinSheet), findsOneWidget);
      expect(find.text('모임 프로필 설정'), findsOneWidget);
      // Rebuilding the background must not open a second sheet.
      // ignore: invalid_use_of_internal_member
      Supabase.instance.client.auth.notifyAllSubscribers(
        AuthChangeEvent.tokenRefreshed,
      );
      await frames();
      expect(groups.membershipReads, 1);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('이 프로필로 참여하기'));
      await frames();
      expect(groups.joins, 1);
      expect(groups.birthdayPublic, false);
      expect(router.routeInformationProvider.value.uri.path, '/group_detail');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['groupId'],
        'invited-group',
      );
      expect(find.byType(GroupJoinSheet), findsNothing);
      // A detail lookup error is retryable rather than an endless spinner.
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.textContaining('private lookup'), findsNothing);
      expect(find.byType(GroupDetailScreen), findsOneWidget);
      router.go('/home');
      await frames();
      groups.failMembership = true;
      router.go('/invite?groupId=second-group');
      await frames();
      expect(find.text('초대 정보를 확인하지 못했습니다.'), findsOneWidget);
      expect(find.text('이 프로필로 참여하기'), findsNothing);
      groups.failMembership = false;
      await tester.tap(find.text('다시 시도'));
      await frames();
      expect(find.text('모임 프로필 설정'), findsOneWidget);
      expect(groups.joins, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames();
      expect(tester.takeException(), isNull);
      await locator.reset();
      router.dispose();
    },
  );
}

class _Users extends UserRepository {
  @override
  Future<UserModel?> fetchMyGlobalProfile() async => UserModel(
    id: Supabase.instance.client.auth.currentUser!.id,
    displayName: 'Name',
  );
}

class _Groups extends GroupRepository {
  int membershipReads = 0, joins = 0;
  bool failMembership = false;
  bool? birthdayPublic;
  @override
  Future<List<Map<String, dynamic>>> fetchMyGroups() async => [];
  @override
  Future<Map<String, dynamic>?> fetchMyMembership(String id) async {
    membershipReads++;
    if (failMembership) throw StateError('private lookup');
    return null;
  }

  @override
  Future<String> fetchGroupName(String id) async => 'Invited group';
  @override
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(String id) async =>
      throw StateError('private lookup');
  @override
  Future<void> joinGroup({
    required String groupId,
    required String nickname,
    String? profileImageUrl,
    bool isBirthdayPublic = true,
  }) async {
    joins++;
    birthdayPublic = isBirthdayPublic;
  }
}

class _Feeds extends MeetupRepository {
  @override
  Future<List<MeetupModel>> fetchHomeFeeds({
    int offset = 0,
    int limit = 5,
  }) async => [];
}

class _Memory extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

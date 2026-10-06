import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Supabase's existing HTTP transport is replaced only inside this test.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:morak/main.dart';
import 'package:morak/locator.dart';
import 'package:morak/router.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/models/user_model.dart';
import 'package:morak/providers/home_provider.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const accountA = '00000000-0000-0000-0000-000000000001';
const accountB = '00000000-0000-0000-0000-000000000002';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'auth routing and feed reject stale sessions and preserve refresh',
    (tester) async {
      // === 수정한 내용: 실제 앱 흐름의 인증과 캐시 문제를 assertion 제외 없이 검증한다 ===
      await Supabase.initialize(
        url: 'http://127.0.0.1:1',
        publishableKey: 'test-only-public-key',
        debug: false,
        httpClient: MockClient((_) async => http.Response('', 204)),
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUri: false,
          pkceAsyncStorage: _MemoryPkce(),
        ),
      );
      final auth = Supabase.instance.client.auth;
      final users = _Users();
      final feeds = _Feeds();
      locator.registerSingleton<UserRepository>(users);
      locator.registerSingleton<MeetupRepository>(feeds);
      locator.registerSingleton<GroupRepository>(_Groups());

      Future<void> pumpFrames() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> login(String id) async {
        await auth.recoverSession(
          jsonEncode({
            'access_token': 'local-test-token',
            'refresh_token': 'local-test-refresh',
            'token_type': 'bearer',
            'user': {
              'id': id,
              'aud': 'authenticated',
              'created_at': '2026-10-05T00:00:00Z',
            },
          }),
        );
        await pumpFrames();
      }

      await tester.pumpWidget(const ProviderScope(child: MorakApp()));
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      await login(accountA);
      // === 수정한 내용: 로그인·로그아웃 안내가 기존 인증 이동과 함께 제공되는지 검증한다 ===
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MorakApp)),
      );
      expect(container.read(feedProvider).requireValue.single.id, accountA);
      expect(feeds.fetchAccounts, [accountA]);

      await auth.signOut(scope: SignOutScope.local);
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(container.read(feedProvider).requireValue, isEmpty);
      expect(find.text('로그아웃되었습니다.'), findsOneWidget);
      feeds.blockNext = true;
      await login(accountB);
      expect(container.read(feedProvider).isLoading, isTrue);
      expect(container.read(feedProvider).value, isEmpty);
      feeds.pending!.complete([_feed(accountB)]);
      await pumpFrames();
      expect(auth.currentUser!.id, accountB);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(container.read(feedProvider).requireValue.single.id, accountB);
      expect(feeds.fetchAccounts, [accountA, accountB]);

      // Direct identity replacement must clear data during the new request too.
      feeds.blockNext = true;
      await login(accountA);
      expect(container.read(feedProvider).isLoading, isTrue);
      expect(container.read(feedProvider).value, isEmpty);
      feeds.pending!.complete([_feed(accountA)]);
      await pumpFrames();
      await login(accountB);

      // An old first-page response must not replace the new account's feed.
      feeds.blockNext = true;
      container.invalidate(feedProvider);
      await tester.pump();
      final oldFirstPage = feeds.pending!;
      await login(accountA);
      oldFirstPage.complete([_feed(accountB)]);
      await pumpFrames();
      expect(container.read(feedProvider).requireValue.single.id, accountA);

      // An old pagination response must not append data or change hasMore.
      feeds.fullPage = true;
      container.invalidate(feedProvider);
      await pumpFrames();
      feeds.blockNext = true;
      final oldPagination = container.read(feedProvider.notifier).loadMore();
      final oldPage = feeds.pending!;
      await auth.signOut(scope: SignOutScope.local);
      await pumpFrames();
      await login(accountB);
      oldPage.complete([]);
      await oldPagination;
      expect(
        container
            .read(feedProvider)
            .requireValue
            .every((f) => f.id == accountB),
        isTrue,
      );
      expect(container.read(feedProvider.notifier).hasMore, isTrue);

      // Even signing back into the same ID must invalidate the earlier session.
      feeds.blockNext = true;
      final oldSameUserPagination = container
          .read(feedProvider.notifier)
          .loadMore();
      final oldSameUserPage = feeds.pending!;
      await auth.signOut(scope: SignOutScope.local);
      await pumpFrames();
      await login(accountB);
      oldSameUserPage.complete([_feed('stale-session')]);
      await oldSameUserPagination;
      expect(
        container
            .read(feedProvider)
            .requireValue
            .every((f) => f.id == accountB),
        isTrue,
      );

      // Stale request failures must not become errors in the new session.
      feeds.blockNext = true;
      final oldFailure = container.read(feedProvider.notifier).loadMore();
      final oldFailedPage = feeds.pending!;
      await login(accountA);
      oldFailedPage.completeError(StateError('old request failed'));
      await oldFailure;
      expect(container.read(feedProvider).hasError, isFalse);
      expect(
        container
            .read(feedProvider)
            .requireValue
            .every((f) => f.id == accountA),
        isTrue,
      );

      // === 수정한 내용: 중복 스크롤 요청과 실패한 페이지의 재시도를 인증 회귀 테스트에 추가한다 ===
      feeds.blockNext = true;
      final notifier = container.read(feedProvider.notifier);
      final beforePaginationCalls = feeds.fetchAccounts.length;
      final firstLoad = notifier.loadMore();
      final duplicateLoad = notifier.loadMore();
      expect(feeds.fetchAccounts.length, beforePaginationCalls + 1);
      expect(notifier.isLoadingMore, isTrue);
      feeds.pending!.complete(List.generate(5, (_) => _feed(accountA)));
      await firstLoad;
      await duplicateLoad;
      expect(container.read(feedProvider).requireValue.length, 10);
      feeds.failNext = true;
      await notifier.loadMore();
      final failedOffset = feeds.fetchOffsets.last;
      expect(notifier.loadMoreError, isNotNull);
      expect(container.read(feedProvider).requireValue.length, 10);
      await notifier.loadMore();
      expect(feeds.fetchOffsets.last, failedOffset);
      expect(container.read(feedProvider).requireValue.length, 15);
      expect(notifier.loadMoreError, isNull);

      // Same-user refresh preserves both route and cached feed without a query.
      router.go('/profile-setup');
      await pumpFrames();
      unawaited(
        router.routerDelegate.navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Current detail')),
          ),
        ),
      );
      await pumpFrames();
      final profileCalls = users.calls;
      final feedCalls = feeds.fetchAccounts.length;
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');
      expect(find.text('Current detail'), findsOneWidget);
      expect(users.calls, profileCalls);
      expect(feeds.fetchAccounts.length, feedCalls);

      // Google ID-token/OAuth success reaches this same signedIn SDK event.
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('로그인되었습니다.'), findsOneWidget);

      // Delay A's login profile, then sign B in without a profile.
      await auth.signOut(scope: SignOutScope.local);
      await pumpFrames();
      users.blockNext = true;
      await login(accountA);
      expect(users.pendingAccount, accountA);
      final oldProfile = users.pending!;
      users.missingAccounts.add(accountB);
      await auth.signOut(scope: SignOutScope.local);
      await pumpFrames();
      await login(accountB);
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');
      oldProfile.complete(UserModel(id: accountA, displayName: 'Account A'));
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');

      // Same-user token refresh must not cancel an in-flight login lookup.
      users.blockNext = true;
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await tester.pump();
      final currentProfile = users.pending!;
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
      await tester.pump();
      currentProfile.complete(
        UserModel(id: accountB, displayName: 'Account B'),
      );
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/home');

      // Existing startup SplashScreen decides home/profile-setup itself.
      users.missingAccounts.clear();
      users.blockNext = true;
      router.go('/');
      await tester.pump();
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      final startupProfile = users.pending!;
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.initialSession);
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      startupProfile.complete(
        UserModel(id: accountB, displayName: 'Account B'),
      );
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      users.missingAccounts.add(accountB);
      router.go('/');
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');

      // Splash also owns an async lookup: do not apply it after an account change.
      await login(accountA);
      users.blockNext = true;
      router.go('/');
      await tester.pump();
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      final staleStartupProfile = users.pending!;
      users.blockNext = true;
      await login(accountB);
      final newLoginProfile = users.pending!;
      staleStartupProfile.complete(UserModel(id: accountA, displayName: 'A'));
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/');
      newLoginProfile.complete(null);
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');

      // Disposing the root cancels both the listener and pending navigation.
      users.blockNext = true;
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await tester.pump();
      final disposedProfile = users.pending!;
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFrames();
      final callsAfterDispose = users.calls;
      disposedProfile.complete(
        UserModel(id: accountB, displayName: 'Account B'),
      );
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await pumpFrames();
      expect(users.calls, callsAfterDispose);
      expect(router.routeInformationProvider.value.uri.path, '/profile-setup');

      // Mount a fresh app with a restored session and a replayed refresh event.
      // Startup must still be owned by Splash, with no duplicate auth lookup.
      // ignore: invalid_use_of_internal_member
      auth.notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
      router.go('/');
      users.blockNext = true;
      await tester.pumpWidget(const ProviderScope(child: MorakApp()));
      await pumpFrames();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(users.calls, callsAfterDispose + 1);
      users.pending!.complete(UserModel(id: accountB, displayName: 'B'));
      await pumpFrames();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFrames();
      await locator.reset();
      router.dispose();
    },
  );
}

class _Users extends UserRepository {
  int calls = 0;
  bool blockNext = false;
  String? pendingAccount;
  Completer<UserModel?>? pending;
  final missingAccounts = <String>{};

  @override
  Future<UserModel?> fetchMyGlobalProfile() {
    calls++;
    final id = Supabase.instance.client.auth.currentUser!.id;
    if (blockNext) {
      blockNext = false;
      pendingAccount = id;
      pending = Completer<UserModel?>();
      return pending!.future;
    }
    return Future.value(
      missingAccounts.contains(id)
          ? null
          : UserModel(id: id, displayName: 'Test user'),
    );
  }
}

class _Feeds extends MeetupRepository {
  final fetchAccounts = <String>[];
  final fetchOffsets = <int>[];
  bool failNext = false;
  bool blockNext = false;
  bool fullPage = false;
  Completer<List<MeetupModel>>? pending;

  @override
  Future<List<MeetupModel>> fetchHomeFeeds({
    int offset = 0,
    int limit = 5,
  }) async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return [];
    fetchAccounts.add(id);
    fetchOffsets.add(offset);
    if (failNext) {
      failNext = false;
      throw StateError('private failure');
    }
    if (blockNext) {
      blockNext = false;
      pending = Completer<List<MeetupModel>>();
      return pending!.future;
    }
    return List.generate(fullPage ? limit : 1, (_) => _feed(id));
  }
}

MeetupModel _feed(String id) => MeetupModel(
  id: id,
  groupId: 'test-group',
  date: '2026-10-05',
  photos: [],
  attendanceMemberIds: [],
);

class _Groups extends GroupRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchMyGroups() async => [];
}

class _MemoryPkce extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/user_model.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/screens/profile/profile_edit_screen.dart';
import 'package:morak/screens/group/group_create_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 프로필 누락과 조회 오류가 무한 로딩이나 불완전한 저장으로 이어지지 않는지 확인한다 ===
void main() {
  late _Users users;
  setUp(() {
    users = _Users();
    locator.registerSingleton<UserRepository>(users);
    locator.registerSingleton<GroupRepository>(
      GroupRepository(client: dummy()),
    );
  });
  tearDown(() => locator.reset());
  testWidgets('missing profile blocks editing and allows retry', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsNothing);
    users.profile = UserModel(id: 'user', displayName: 'Loaded name');
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Loaded name',
    );
    expect(users.saves, 0);
  });
  testWidgets(
    'group creation lookup failure is retryable and hides internal details',
    (tester) async {
      users.fail = true;
      await tester.pumpWidget(const MaterialApp(home: GroupCreateScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('private query'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      users.fail = false;
      users.profile = UserModel(id: 'user', displayName: 'Loaded name');
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('다시 시도'), findsNothing);
      expect(users.saves, 0);
    },
  );
  testWidgets('profile response after disposal does not touch controllers', (
    tester,
  ) async {
    users.pending = Completer<UserModel?>();
    await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    users.pending!.complete(UserModel(id: 'user', displayName: 'Late name'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(users.saves, 0);
  });
}

SupabaseClient dummy() => SupabaseClient(
  'http://localhost:1',
  'test-public-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _Users extends UserRepository {
  _Users() : super(client: dummy());
  UserModel? profile;
  bool fail = false;
  int saves = 0;
  Completer<UserModel?>? pending;
  @override
  Future<UserModel?> fetchMyGlobalProfile() async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('private query');
    return profile;
  }
}

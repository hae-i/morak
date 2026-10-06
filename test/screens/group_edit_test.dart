import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/widgets/group/group_edit_sheets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 테마 선택 반환 타입과 이름 변경 시 기존 색상 보존을 실제 시트로 검증한다 ===
void main() {
  testWidgets(
    'theme picker returns typed result without a runtime cast error',
    (tester) async {
      final repo = _Groups();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupEditSheet(
              groupId: 'group',
              initialName: 'Name',
              initialEmoji: 'A',
              initialColor: '#123456',
              repository: repo,
              onUpdated: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('모임 정보 수정'), findsOneWidget);
    },
  );
  testWidgets('changing only name preserves a custom HEX theme', (
    tester,
  ) async {
    final repo = _Groups();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupEditSheet(
            groupId: 'group',
            initialName: 'Name',
            initialColor: '#123456',
            repository: repo,
            onUpdated: () {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Changed name');
    await tester.tap(find.text('수정 완료'));
    await tester.pump();
    expect(repo.name, 'Changed name');
    expect(repo.color, '#123456');
    expect(tester.takeException(), isNull);
  });
}

class _Groups extends GroupRepository {
  _Groups()
    : super(
        client: SupabaseClient(
          'http://localhost:1',
          'test-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  String? name, color;
  @override
  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? hexColor,
    String? emoji,
    XFile? newCoverImage,
    String? existingCoverUrl,
    XFile? newLogoImage,
    String? existingLogoUrl,
  }) async {
    this.name = name;
    color = hexColor;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/widgets/group/member_manage_sheet.dart';

// === 수정한 내용: 기존 복수 방장 모임의 위임과 강등 메뉴가 서로 다른 작업을 호출하는지 확인한다 ===
void main() {
  testWidgets(
    'existing host can receive transfer without losing demotion action',
    (tester) async {
      var transferred = 0;
      var demoted = 0;
      final member = MemberModel(
        id: 'other',
        userId: 'other-user',
        displayName: 'Other',
        role: 'host',
        isBirthdayPublic: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('관리'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => MemberManageSheet(
                    member: member,
                    onKick: () {},
                    onChangeRole: () => demoted++,
                    onTransferHost: () => transferred++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('방장 위임'));
      await tester.pumpAndSettle();
      expect(transferred, 1);
      expect(demoted, 0);
      await tester.tap(find.text('관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반 멤버로 강등'));
      await tester.pumpAndSettle();
      expect(transferred, 1);
      expect(demoted, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

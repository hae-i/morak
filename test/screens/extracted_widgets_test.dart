import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/utils/ui_utils.dart';
import 'package:morak/widgets/group/member_profile_sheet.dart';
import 'package:morak/widgets/profile/birthday_field.dart';

// === 수정한 내용: 추출한 UI의 생일 공개·본인 편집·날짜 취소 및 확정 동작을 확인한다 ===
void main() {
  MemberModel member({bool birthdayPublic = false}) => MemberModel(
    id: 'm',
    userId: 'u',
    displayName: 'Name',
    role: 'member',
    isBirthdayPublic: birthdayPublic,
    birthday: '2000-03-12',
    attendedCount: 2,
    attendanceRate: 50,
  );
  testWidgets('other member keeps birthday private and has no edit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberProfileSheet(
            member: member(),
            isMe: false,
            onEdit: () => fail('unexpected edit'),
          ),
        ),
      ),
    );
    expect(find.textContaining('생일:'), findsNothing);
    expect(find.byTooltip('프로필 수정'), findsNothing);
    expect(find.text('2회'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('own member exposes edit callback and public birthday', (
    tester,
  ) async {
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberProfileSheet(
            member: member(birthdayPublic: true),
            isMe: true,
            onEdit: () => edits++,
          ),
        ),
      ),
    );
    expect(find.textContaining('2000. 03. 12'), findsOneWidget);
    await tester.tap(find.byTooltip('프로필 수정'));
    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'birthday picker preserves date on cancel and returns confirmation',
    (tester) async {
      DateTime? selected = DateTime(2000, 3, 12);
      var updates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BirthdayField(
                value: selected,
                onTap: () async {
                  final picked = await UiUtils.pickBirthday(
                    context: context,
                    selected: selected,
                  );
                  if (!context.mounted || picked == null) return;
                  setState(() {
                    selected = picked;
                    updates++;
                  });
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('2000-03-12'), findsOneWidget);
      await tester.tap(find.text('2000-03-12'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        selected,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(updates, 0);
      expect(find.text('2000-03-12'), findsOneWidget);
      await tester.tap(find.text('2000-03-12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(updates, 1);
      expect(find.text('2000-03-12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

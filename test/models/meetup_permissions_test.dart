// === 수정한 내용: 작성자·방장·부방장·탈퇴 멤버별 기록 권한과 개인정보 가림을 검증한다 ===
import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/models/meetup_model.dart';

MemberModel member(String id, String role, {bool deleted = false}) =>
    MemberModel(
      id: id,
      userId: id,
      displayName: id,
      role: role,
      isDeleted: deleted,
      isBirthdayPublic: false,
    );
MeetupModel post({String? author = 'author', bool deleted = false}) =>
    MeetupModel(
      id: 'post',
      groupId: 'group',
      authorMemberId: author,
      authorName: 'Writer',
      authorDeleted: deleted,
      date: '2026-10-07',
      photos: [],
      attendanceMemberIds: [],
    );
void main() {
  test('only active author edits; managers and author can delete', () {
    final record = post();
    expect(record.canEdit(member('author', 'member')), isTrue);
    expect(record.canDelete(member('author', 'member')), isTrue);
    for (final role in ['host', 'deputy']) {
      expect(record.canEdit(member('other', role)), isFalse);
      expect(record.canDelete(member('other', role)), isTrue);
    }
    expect(record.canEdit(member('other', 'member')), isFalse);
    expect(record.canDelete(member('other', 'member')), isFalse);
    expect(record.canEdit(null), isFalse);
    expect(record.canDelete(null), isFalse);
  });
  test('deleted and unknown authors are managed only by active managers', () {
    for (final record in [post(deleted: true), post(author: null)]) {
      for (final role in ['host', 'deputy']) {
        expect(record.canEdit(member('manager', role)), isTrue);
        expect(record.canDelete(member('manager', role)), isTrue);
        expect(record.canEdit(member('manager', role, deleted: true)), isFalse);
        expect(
          record.canDelete(member('manager', role, deleted: true)),
          isFalse,
        );
      }
      expect(record.canEdit(member('other', 'member')), isFalse);
    }
    expect(post(deleted: true).authorLabel, '탈퇴한 멤버');
  });
  test('deleted membership retains attendance identifier and hides personal fields', () {
    final tombstone = MemberModel.fromJson({
      'id': 'old-member',
      'user_id': 'account',
      'display_name': 'Private name',
      'role': 'deputy',
      'is_deleted': true,
      'profile_image_url': 'private-url',
      'is_birthday_public': true,
      'users': {'birthday': '2000-01-01'},
      'attended_count': 3,
    });
    expect(tombstone.id, 'old-member');
    expect(tombstone.attendedCount, 3);
    expect(tombstone.displayName, '탈퇴한 멤버');
    expect(tombstone.profileImageUrl, isNull);
    expect(tombstone.birthday, isNull);
    expect(tombstone.isBirthdayPublic, isFalse);
    expect(tombstone.isManager, isFalse);
  });
}

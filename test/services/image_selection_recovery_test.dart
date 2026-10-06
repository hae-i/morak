import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morak/services/image_selection_recovery.dart';

// === 수정한 내용: 재시작 복구가 계정과 모임을 넘지 않고 새 사진 선택에도 남는지 검증한다 ===
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImageSelectionRecovery recovery;
  int reads = 0;
  setUp(() {
    reads = 0;
    SharedPreferences.setMockInitialValues({'morak.image_selection': jsonEncode({
      'userId': 'A', 'target': 'meetup:group1:new', 'created': DateTime.now().toIso8601String()})});
    recovery = ImageSelectionRecovery(retrieve: () async {
      reads++; return LostDataResponse(files: [XFile('/cache/photo.jpg')], type: RetrieveType.image);
    });
  });
  test('startup retrieves once and restores only the original identity and target', () async {
    await recovery.initialize(); await recovery.initialize();
    expect(reads, 1);
    expect(await recovery.recover('B', 'meetup:group1:new'), isEmpty);
    expect(await recovery.recover('A', 'meetup:group2:new'), isEmpty);
    expect((await recovery.recover('A', 'meetup:group1:new')).single.path, '/cache/photo.jpg');
  });
  test('beginning a different selection preserves already recovered files', () async {
    await recovery.initialize(); await recovery.begin('A', 'global-profile');
    await recovery.clear('A', 'global-profile');
    expect(await recovery.recover('A', 'meetup:group1:new'), hasLength(1));
    await recovery.clear('A', 'meetup:group1:new');
    expect(await recovery.recover('A', 'meetup:group1:new'), isEmpty);
  });
  test('recovered metadata persists through a second Dart process restart', () async {
    await recovery.initialize();
    final restarted = ImageSelectionRecovery(retrieve: () async => LostDataResponse.empty());
    expect(await restarted.recover('A', 'meetup:group1:new'), hasLength(1));
  });
  test('metadata older than one day is not used', () async {
    SharedPreferences.setMockInitialValues({'morak.image_selection': jsonEncode({
      'userId': 'A', 'target': 'meetup:group1:new', 'created': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()})});
    await recovery.initialize(); expect(await recovery.recover('A', 'meetup:group1:new'), isEmpty);
  });
  test('retrieve failure allows a subsequent initialization rather than disabling the picker', () async {
    int attempts = 0;
    final failing = ImageSelectionRecovery(retrieve: () async {
      if (attempts++ == 0) throw StateError('temporary failure');
      return LostDataResponse.empty();
    });
    await expectLater(failing.initialize(), throwsStateError);
    await failing.initialize(); expect(attempts, 2);
  });
}

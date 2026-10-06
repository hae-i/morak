import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:morak/models/group_detail_data.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/providers/group_detail_controller.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 분리된 상세 상태의 늦은 결과·중복 요청·재시도·폐기 동작을 UI 없이 검증한다 ===
void main() {
  late SupabaseClient client;
  late _Groups repo;
  late GroupDetailController controller;
  setUp(() {
    client = SupabaseClient(
      'http://localhost:1',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repo = _Groups(client);
    controller = GroupDetailController(repository: repo, groupId: 'g');
  });
  tearDown(() async {
    controller.dispose();
    await client.dispose();
  });

  test(
    'typed detail preserves totals and associates photos with their record',
    () async {
      expect(await controller.load(), GroupDetailLoadResult.success);
      expect(controller.totalMeetups, 3);
      expect(
        controller.albumPhotos.single.url,
        'https://example.invalid/first.jpg',
      );
      expect(controller.albumPhotos.single.meetup.id, 'first');
      expect(() => controller.meetups.clear(), throwsUnsupportedError);
    },
  );
  test(
    'older load failure cannot overwrite a newer successful refresh',
    () async {
      final old = Completer<GroupDetailData>();
      repo.detail = () => old.future;
      final firstLoad = controller.load();
      repo.detail = () async => data('new');
      await controller.load(silent: true);
      old.completeError(StateError('old failure'));
      expect(await firstLoad, GroupDetailLoadResult.discarded);
      expect(controller.group!.name, 'new');
      expect(controller.isLoading, false);
    },
  );
  test(
    'duplicate page calls are locked and refresh discards the pending page',
    () async {
      await controller.load();
      final old = Completer<List<MeetupModel>>();
      repo.page = (_) => old.future;
      final page = controller.loadMore();
      await controller.loadMore();
      expect(repo.offsets, [1]);
      await controller.load(silent: true);
      old.complete([record('old')]);
      await page;
      expect(controller.meetups.map((m) => m.id), ['first']);
      expect(controller.isLoadingMore, false);
    },
  );
  test('failed page keeps offset, then retry deduplicates rows and preserves photo mapping', () async {
    await controller.load();
    repo.page = (_) async => throw StateError('failed');
    await controller.loadMore();
    expect(controller.pageFailed, true);
    repo.page = (_) async => [record('first'), record('next')];
    await controller.loadMore();
    expect(repo.offsets, [1, 1]);
    expect(controller.meetups.map((m) => m.id), ['first', 'next']);
    expect(controller.albumPhotos.map((p) => p.meetup.id), ['first', 'next']);
    expect(controller.hasMore, false);
    expect(controller.pageFailed, false);
  });
  test(
    'failed silent refresh retains saved data and releases the page lock',
    () async {
      await controller.load();
      repo.detail = () async => throw StateError('refresh failed');
      expect(await controller.load(silent: true), GroupDetailLoadResult.failed);
      expect(controller.group!.name, 'first');
      repo.page = (_) async => [record('next'), record('last')];
      await controller.loadMore();
      expect(controller.meetups.length, 3);
    },
  );
  test('disposed state never applies or notifies late loads', () async {
    final old = Completer<GroupDetailData>();
    repo.detail = () => old.future;
    final temporary = GroupDetailController(repository: repo, groupId: 'g');
    var notifications = 0;
    temporary.addListener(() => notifications++);
    final loading = temporary.load();
    temporary.dispose();
    old.complete(data('late'));
    expect(await loading, GroupDetailLoadResult.discarded);
    expect(notifications, 1);
    expect(temporary.group, isNull);
  });
}

MeetupModel record(String id) => MeetupModel(
  id: id,
  groupId: 'g',
  date: '2026-10-06',
  photos: ['https://example.invalid/$id.jpg'],
  attendanceMemberIds: [],
);
GroupDetailData data(String name) => GroupDetailData(
  group: GroupModel(id: 'g', name: name),
  meetups: [record('first')],
  rankedMembers: [],
  totalMeetups: 3,
  paged: true,
);

class _Groups extends GroupRepository {
  _Groups(SupabaseClient client) : super(client: client);
  Future<GroupDetailData> Function() detail = () async => data('first');
  Future<List<MeetupModel>> Function(int) page = (_) async => [];
  final offsets = <int>[];
  @override
  Future<GroupDetailData> fetchGroupDetail(String groupId) => detail();
  @override
  Future<List<MeetupModel>> fetchMeetupPage(
    String groupId, {
    int offset = 0,
    int limit = 40,
  }) {
    offsets.add(offset);
    return page(offset);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meetup_model.dart';
import '../locator.dart';
import '../repositories/meetup_repository.dart';

// 🌟 데이터를 누적해서 들고 있고, "더 가져와!" 명령을 수행
class FeedNotifier extends AsyncNotifier<List<MeetupModel>> {
  int _offset = 0;
  final int _limit = 5; // 한 번에 5개씩
  bool hasMore = true; // 더 가져올 데이터가 남아있는지 확인하는 변수

  @override
  Future<List<MeetupModel>> build() async {
    _offset = 0;
    hasMore = true;
    return _fetchData();
  }

  Future<List<MeetupModel>> _fetchData() async {
    final repo = locator<MeetupRepository>();
    final newFeeds = await repo.fetchHomeFeeds(offset: _offset, limit: _limit);

    // 💡 가져온 게 5개보다 적다면? -> "아하, 이제 DB에 남은 피드가 없구나!"
    if (newFeeds.length < _limit) hasMore = false;
    return newFeeds;
  }

  // 🌟 스크롤 맨 밑에 닿으면 호출할 함수
  Future<void> loadMore() async {
    // 로딩 중이거나, 더 이상 가져올 게 없으면 일찍 종료
    if (state.isLoading || state.isRefreshing || state.isReloading || !hasMore)
      return;

    _offset += _limit; // 그 다음 5개를 위해 오프셋을 증가시킴
    final newFeeds = await _fetchData();

    // 🌟 기존에 있던 리스트(state.value) 뒤에 새 리스트(newFeeds)를 이어 붙임
    state = AsyncData([...state.value ?? [], ...newFeeds]);
  }
}

// 🌟 위에서 만든 스마트 배달부를 앱에 등록
final feedProvider = AsyncNotifierProvider<FeedNotifier, List<MeetupModel>>(
  FeedNotifier.new,
);

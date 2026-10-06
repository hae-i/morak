import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meetup_model.dart';
import '../locator.dart';
import '../repositories/meetup_repository.dart';

// 🌟 데이터를 누적해서 들고 있고, "더 가져와!" 명령을 수행
class FeedNotifier extends AsyncNotifier<List<MeetupModel>> {
  int _offset = 0;
  final int _limit = 5; // 한 번에 5개씩
  bool hasMore = true; // 더 가져올 데이터가 남아있는지 확인하는 변수
  int _generation = 0;
  bool isLoadingMore = false;
  Object? loadMoreError;

  void resetForSession() {
    // === 수정한 내용: 계정 변경 시 이전 데이터와 페이지 상태를 비우고 늦은 응답을 무효화한다 ===
    _generation++;
    _offset = 0;
    hasMore = true;
    isLoadingMore = false;
    loadMoreError = null;
    // AsyncLoading retains previous data in Riverpod; clear it first.
    state = const AsyncData([]);
    state = const AsyncLoading();
    ref.invalidateSelf(asReload: true);
  }

  @override
  Future<List<MeetupModel>> build() async {
    _offset = 0;
    hasMore = true;
    isLoadingMore = false;
    loadMoreError = null;
    final generation = ++_generation;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final feeds = await _fetchData(offset: 0);
    if (_isCurrent(generation, userId)) hasMore = feeds.length >= _limit;
    return feeds;
  }

  bool _isCurrent(int generation, String userId) =>
      ref.mounted &&
      generation == _generation &&
      Supabase.instance.client.auth.currentUser?.id == userId;

  Future<List<MeetupModel>> _fetchData({required int offset}) async {
    final repo = locator<MeetupRepository>();
    return repo.fetchHomeFeeds(offset: offset, limit: _limit);
  }

  // 🌟 스크롤 맨 밑에 닿으면 호출할 함수
  Future<void> loadMore() async {
    // 로딩 중이거나, 더 이상 가져올 게 없으면 일찍 종료
    if (state.isLoading ||
        state.isRefreshing ||
        state.isReloading ||
        !hasMore ||
        isLoadingMore) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final generation = _generation;
    // === 수정한 내용: 추가 조회를 잠그고 성공한 페이지에만 offset을 반영하여 중복과 누락을 방지한다 ===
    final nextOffset = _offset + _limit;
    isLoadingMore = true;
    loadMoreError = null;
    List<MeetupModel> newFeeds;
    try {
      newFeeds = await _fetchData(offset: nextOffset);
    } catch (error) {
      if (!_isCurrent(generation, userId)) return;
      loadMoreError = error;
      state = AsyncData([...state.value ?? []]);
      return;
    } finally {
      if (_isCurrent(generation, userId)) isLoadingMore = false;
    }
    if (!_isCurrent(generation, userId)) return;
    _offset = nextOffset;
    hasMore = newFeeds.length >= _limit;

    // 🌟 기존에 있던 리스트(state.value) 뒤에 새 리스트(newFeeds)를 이어 붙임
    state = AsyncData([...state.value ?? [], ...newFeeds]);
  }
}

// 🌟 위에서 만든 스마트 배달부를 앱에 등록
final feedProvider = AsyncNotifierProvider<FeedNotifier, List<MeetupModel>>(
  FeedNotifier.new,
);

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/group_detail_data.dart';
import '../models/group_model.dart';
import '../models/meetup_model.dart';
import '../models/member_model.dart';
import '../repositories/group_repository.dart';

enum GroupDetailLoadResult { success, failed, discarded }

// === 수정한 내용: 화면 소유 상태 객체로 조회·페이지·앨범 처리를 옮기고 기존 요청 세대 보호를 유지한다 ===
// 화면과 함께 dispose하며 전역 캐시나 새로운 상태관리 라이브러리를 도입하지 않습니다.
class GroupDetailController extends ChangeNotifier {
  final GroupRepository repository;
  final String groupId;
  GroupDetailController({required this.repository, required this.groupId});

  bool _disposed = false;
  int _generation = 0;
  int _offset = 0;
  bool _refreshInProgress = false;
  bool _isLoading = true;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _pageFailed = false;
  int _totalMeetups = 0;
  GroupModel? _group;
  List<MeetupModel> _meetups = [];
  List<MemberModel> _rankedMembers = [];
  final List<AlbumPhoto> _albumPhotos = [];

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get pageFailed => _pageFailed;
  int get totalMeetups => _totalMeetups;
  GroupModel? get group => _group;
  List<MeetupModel> get meetups => UnmodifiableListView(_meetups);
  List<MemberModel> get rankedMembers => UnmodifiableListView(_rankedMembers);
  List<AlbumPhoto> get albumPhotos => UnmodifiableListView(_albumPhotos);
  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<GroupDetailLoadResult> load({bool silent = false}) async {
    if (_disposed) return GroupDetailLoadResult.discarded;
    final generation = ++_generation;
    _isLoadingMore = false;
    _refreshInProgress = true;
    if (!silent) _isLoading = true;
    notifyListeners();
    try {
      final data = await repository.fetchGroupDetail(groupId);
      if (!_isCurrent(generation)) return GroupDetailLoadResult.discarded;
      _group = data.group;
      _meetups = List.of(data.meetups);
      _rankedMembers = List.of(data.rankedMembers);
      _totalMeetups = data.totalMeetups;
      _offset = _meetups.length;
      _hasMore = data.paged && _offset < _totalMeetups;
      _pageFailed = false;
      _albumPhotos.clear();
      _appendPhotos(_meetups);
      return GroupDetailLoadResult.success;
    } catch (_) {
      if (!_isCurrent(generation)) return GroupDetailLoadResult.discarded;
      return GroupDetailLoadResult.failed;
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        _refreshInProgress = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed ||
        _isLoading ||
        _refreshInProgress ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    final generation = _generation;
    _isLoadingMore = true;
    _pageFailed = false;
    notifyListeners();
    try {
      final page = await repository.fetchMeetupPage(groupId, offset: _offset);
      if (!_isCurrent(generation)) return;
      if (page.isEmpty) throw StateError('Group records changed');
      final ids = _meetups.map((record) => record.id).toSet();
      final additions = page.where((record) => ids.add(record.id)).toList();
      _offset += page.length;
      _meetups.addAll(additions);
      _appendPhotos(additions);
      _hasMore = _offset < _totalMeetups;
    } catch (_) {
      if (_isCurrent(generation)) _pageFailed = true;
    } finally {
      if (_isCurrent(generation)) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void _appendPhotos(Iterable<MeetupModel> records) {
    for (final record in records) {
      for (final url in record.photos) {
        _albumPhotos.add(AlbumPhoto(url: url, meetup: record));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

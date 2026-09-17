import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/feed_provider.dart';
import '../../widgets/feed/feed_card.dart';

// 🌟 스크롤 컨트롤러 ConsumerStatefulWidget
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});
  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 🌟 스크롤을 내릴 때마다 이 함수가 실행
    _scrollController.addListener(() {
      // 💡 현재 스크롤 위치가 맨 밑바닥에서 50픽셀 이내로 가까워지면?
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        ref.read(feedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '모락모락 피드 ☁️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(feedProvider.future),
        color: AppConstants.primaryColor,
        child: feedState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppConstants.primaryColor),
          ),
          error: (error, stack) =>
              Center(child: Text('피드를 불러오지 못했습니다: $error')),
          data: (feeds) {
            if (feeds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_album_outlined,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 모임에 기록된 피드가 없어요!\n모임에서 기록을 남겨보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              controller: _scrollController, // 🌟 감지기를 리스트에 부착
              physics:
                  const AlwaysScrollableScrollPhysics(), // 내용이 적어도 당겨서 새로고침 되도록
              itemCount: feeds.length + 1, // 🌟 로딩 스피너를 보여주기 위해 +1
              itemBuilder: (context, index) {
                // 💡 맨 마지막 아이템을 그릴 차례일 때
                if (index == feeds.length) {
                  // 더 가져올 데이터가 남아있다면 로딩 스피너를 띄움
                  final hasMore = ref.read(feedProvider.notifier).hasMore;
                  if (hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    );
                  }
                  // 데이터가 더 이상 없으면 빈 공간만
                  return const SizedBox(height: 40);
                }

                // 정상적으로 피드 카드 그리기
                return FeedCard(
                  feed: feeds[index],
                  onLike: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('좋아요 기능은 준비 중입니다! 💖')),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

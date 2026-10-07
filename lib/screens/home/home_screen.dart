import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_provider.dart';
import '../../widgets/feed/feed_card.dart';
import '../../constants/app_constants.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/request_error_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
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
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '홈',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppConstants.textTitle,
          ),
        ),
        backgroundColor: AppConstants.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(feedProvider.future),
        color: AppConstants.primaryColor,
        backgroundColor: AppConstants.cardBackground,
        child: feedState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppConstants.primaryColor),
          ),
          // === 수정한 내용: 최초 조회 오류의 원문을 숨기고 동일 화면에서 재시도를 제공한다 ===
          error: (error, stack) => RequestErrorView(
            message: '피드를 불러오지 못했습니다.',
            onRetry: () => ref.invalidate(feedProvider),
          ),
          data: (feeds) {
            if (feeds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_album_outlined,
                      size: 60,
                      color: AppConstants.secondaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 모임에 기록된 피드가 없어요!\n모임에서 기록을 남겨보세요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppConstants.textCaption,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: feeds.length + 1,
              itemBuilder: (context, index) {
                if (index == feeds.length) {
                  // === 수정한 내용: 추가 조회 실패는 기존 피드를 유지한 채 같은 페이지의 재시도를 제공한다 ===
                  final notifier = ref.read(feedProvider.notifier);
                  final hasMore = notifier.hasMore;
                  if (notifier.loadMoreError != null) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Button(
                        text: '다시 시도',
                        onPressed: notifier.loadMore,
                      ),
                    );
                  }
                  if (hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.black87,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: 40);
                }

                return FeedCard(
                  feed: feeds[index],
                  onLike: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('좋아요 기능은 준비 중입니다')),
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

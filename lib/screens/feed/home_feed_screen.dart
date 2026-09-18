import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/feed_provider.dart';
import '../../widgets/feed/feed_card.dart';

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
      backgroundColor: Colors.white, // 🌟 순백색 배경!
      appBar: AppBar(
        title: const Text(
          '모락모락 피드 ☁️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(feedProvider.future),
        color: Colors.black87, // 🌟 힙하게 블랙 스피너
        backgroundColor: Colors.white,
        child: feedState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.black87),
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
                      size: 60,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 모임에 기록된 피드가 없어요!\n모임에서 기록을 남겨보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 15),
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
                  final hasMore = ref.read(feedProvider.notifier).hasMore;
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

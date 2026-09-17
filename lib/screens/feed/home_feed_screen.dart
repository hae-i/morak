import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/feed_provider.dart';
import '../../widgets/feed/feed_card.dart';

// 🌟 1. StatefulWidget 대신 ConsumerWidget 을 상속
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  // 🌟 2. build 함수에 WidgetRef ref 가 추가 (이 ref 로 데이터를 구독함)
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 3. setState 다 날리고, 한 줄로 데이터 구독
    // ref.watch 는 데이터가 바뀌면 화면을 알아서 다시 그려줍니다.
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
        // 🌟 4. 새로고침 로직도 ref.refresh 로 단 한 줄
        onRefresh: () async => ref.refresh(feedProvider.future),
        color: AppConstants.primaryColor,

        // 🌟 5. feedState의 3가지 상태(로딩중, 에러남, 데이터옴)에 따라 화면을 분기처리
        child: feedState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppConstants.primaryColor),
          ),
          error: (error, stack) =>
              Center(child: Text('피드를 불러오지 못했습니다: $error')),
          data: (feeds) {
            // 데이터가 도착했을 때의 화면 (기존 로직과 동일)
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
              itemCount: feeds.length,
              itemBuilder: (context, index) {
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

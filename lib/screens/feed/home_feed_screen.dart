import 'package:flutter/material.dart';

import '../../constants/app_constants.dart'; // 🌟 상수 임포트
import '../../repositories/group_repository.dart';
import '../../widgets/feed_card.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});
  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _repository = GroupRepository();
  List<dynamic> _feeds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.fetchHomeFeeds();
      if (mounted) setState(() => _feeds = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('피드를 불러오지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onRefresh: _loadFeeds,
        color: AppConstants.primaryColor, // 🌟 하드코딩 색상 교체!
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor,
                ),
              ) // 🌟 교체!
            : _feeds.isEmpty
            ? Center(
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
              )
            : ListView.builder(
                itemCount: _feeds.length,
                itemBuilder: (context, index) {
                  return FeedCard(
                    feed: _feeds[index],
                    onLike: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('좋아요 기능은 준비 중입니다! 💖')),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

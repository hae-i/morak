import 'package:flutter/material.dart';
import '../../repositories/supabase_repository.dart';
import '../../widgets/feed_card.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _repository = SupabaseRepository();
  List<dynamic> _feeds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    setState(() => _isLoading = true);
    // 임시: final data = await _repository.fetchAllFeeds();
    // _feeds = data;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모임 소식 📢')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _feeds.length,
        itemBuilder: (context, index) {
          return FeedCard(
            feed: _feeds[index],
            onLike: () {
              // 좋아요 로직 처리!
            },
          );
        },
      ),
    );
  }
}
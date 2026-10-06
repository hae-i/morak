import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_user_provider.dart';
import '../../widgets/common/request_error_view.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../widgets/group/group_card.dart';
import '../group/group_create_screen.dart';
import '../group/group_detail_screen.dart';

class MyGroupScreen extends ConsumerStatefulWidget {
  const MyGroupScreen({super.key});
  @override
  ConsumerState<MyGroupScreen> createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends ConsumerState<MyGroupScreen> {
  bool _isLoading = true;
  List<dynamic> _myGroups = [];
  bool _loadFailed = false;
  int _loadGeneration = 0;
  String? _userId = Supabase.instance.client.auth.currentUser?.id;

  final _groupRepo = locator<GroupRepository>();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    // === 수정한 내용: 계정 전환과 화면 종료 후 늦은 조회 결과가 이전 모임을 표시하지 않게 한다 ===
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    setState(() => _isLoading = true);
    try {
      final data = await _groupRepo.fetchMyGroups();
      if (!mounted ||
          generation != _loadGeneration ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      setState(() {
        _myGroups = data;
        _loadFailed = false;
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) {
      if (!next.hasValue || next.value == _userId) return;
      _userId = next.value;
      setState(() => _myGroups = []);
      _loadGroups();
    });
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '내 모임',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppConstants.textTitle,
          ),
        ),
        backgroundColor: AppConstants.scaffoldBackground,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              size: 28,
              color: AppConstants.textTitle,
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupCreateScreen(),
                ),
              );
              if (result == true) _loadGroups();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppConstants.primaryColor,
        backgroundColor: AppConstants.cardBackground,
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor,
                  strokeWidth: 2,
                ),
              )
            : _loadFailed
            ? RequestErrorView(
                message: '모임 목록을 불러오지 못했습니다.',
                onRetry: _loadGroups,
              )
            : _myGroups.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_off_rounded,
                      size: 54,
                      color: AppConstants.secondaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '아직 참여중인 모임이 없어요.\n우측 상단 버튼을 눌러보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppConstants.textCaption,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _myGroups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = _myGroups[index];
                  final group = item['group'];

                  return GroupCard(
                    group: group,
                    role: item['role'],
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GroupDetailScreen(groupId: group.id),
                        ),
                      );
                      if (result == true) _loadGroups();
                    },
                  );
                },
              ),
      ),
    );
  }
}

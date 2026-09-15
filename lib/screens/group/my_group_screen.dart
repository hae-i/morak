import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/group_repository.dart';
import '../../widgets/group_card.dart';
import 'group_create_screen.dart';

class MyGroupScreen extends StatefulWidget {
  const MyGroupScreen({super.key});
  @override
  State<MyGroupScreen> createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends State<MyGroupScreen> {
  bool _isLoading = true;
  List<dynamic> _myGroups = [];
  final _groupRepository = GroupRepository(); // 분리한 레포지토리 가져오기

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      // 로직을 레포지토리에 맡기니까 화면 코드가 한 줄로 끝남!
      final data = await _groupRepository.fetchMyGroups();
      setState(() => _myGroups = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('내 모임 ☁️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          // 💡 테스트용 로그아웃 버튼 (나중에 마이페이지로 빼면 됩니다!)
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          )
        ],
      ),
      // 당겨서 새로고침 기능 추가!
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        color: const Color(0xFFFF8A80),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80)))
            : _myGroups.isEmpty
            ? const Center(child: Text('아직 소속된 모임이 없어요.'))
            : ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _myGroups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = _myGroups[index];
            if (item['groups'] == null) return const SizedBox.shrink();

            // 엄청 길었던 UI 코드가 단 한 줄로! ✨
            return GroupCard(
              group: item['groups'],
              role: item['role'],
              onTap: () {
                // 상세 화면 이동
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 💡 새 모임 만들기로 이동! 끝나고 돌아왔을 때 result가 true면 새로고침!
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GroupCreateScreen()),
          );

          if (result == true) {
            _loadGroups();
          }
        },
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 모임', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
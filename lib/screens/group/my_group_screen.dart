import 'package:flutter/material.dart';

import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../widgets/group/group_card.dart';
import '../group/group_create_screen.dart';
import '../group/group_detail_screen.dart';

class MyGroupScreen extends StatefulWidget {
  const MyGroupScreen({super.key});
  @override
  State<MyGroupScreen> createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends State<MyGroupScreen> {
  bool _isLoading = true;
  List<dynamic> _myGroups = [];

  final _groupRepo = locator<GroupRepository>();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final data = await _groupRepo.fetchMyGroups();
      setState(() => _myGroups = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🌟 순백색 배경
      appBar: AppBar(
        title: const Text(
          '내 모임',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              size: 28,
              color: Colors.black87,
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
        color: Colors.black87, // 🌟 블랙 스피너
        backgroundColor: Colors.white,
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.black87,
                  strokeWidth: 2,
                ),
              )
            : _myGroups.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_off_rounded,
                      size: 54,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 등록된 모임이 없어요.\n우측 상단 버튼을 눌러보세요! ☁️',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
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

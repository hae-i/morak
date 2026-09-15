import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_create_screen.dart'; // 💡 앗! 파일명이 다르면 지은님 프로젝트에 맞게 수정해 주세요!

class MyGroupScreen extends StatefulWidget {
  const MyGroupScreen({super.key});

  @override
  State<MyGroupScreen> createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends State<MyGroupScreen> {
  bool _isLoading = true;
  List<dynamic> _myGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchMyGroups(); // 화면이 켜질 때 진짜 데이터를 불러옵니다!
  }

  // 🌟 핵심: 수파베이스에서 내 모임 데이터 불러오기
  Future<void> _fetchMyGroups() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // group_members 테이블에서 나를 찾고, 연결된 groups 테이블 정보까지 한 번에 가져오는 쿼리!
      final data = await Supabase.instance.client
          .from('group_members')
          .select('''
            role,
            joined_at,
            groups (
              id,
              name,
              theme_color,
              theme_emoji
            )
          ''')
          .eq('user_id', userId)
          .order('joined_at', ascending: false); // 최신 가입 순 정렬

      setState(() {
        _myGroups = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('데이터 불러오기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 배경색에 따라 글자색(흰/검)을 자동으로 맞춰주는 함수
  Color _getTextColor(Color bg) {
    return bg.computeLuminance() > 0.6 ? Colors.grey[800]! : Colors.white;
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
        onRefresh: _fetchMyGroups,
        color: const Color(0xFFFF8A80),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80)))
            : _myGroups.isEmpty
            ? ListView( // 당겨서 새로고침을 위해 빈 화면도 ListView로 감쌉니다.
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            const Center(
              child: Text(
                '아직 소속된 모임이 없어요.\n오른쪽 아래 버튼을 눌러 새 모임을 만들어보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _myGroups.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = _myGroups[index];
            final group = item['groups'];

            if (group == null) return const SizedBox.shrink();

            final role = item['role'];

            // 🌟 DB에서 text로 가져온 색상값을 다시 int로 안전하게 변환!
            final String? colorRaw = group['theme_color'];
            final int colorInt = colorRaw != null
                ? (int.tryParse(colorRaw) ?? Colors.grey[200]!.value)
                : Colors.grey[200]!.value;
            final themeColor = Color(colorInt);

            final themeEmoji = group['theme_emoji'] ?? '☁️';
            final groupName = group['name'] ?? '이름 없는 모임';
            final textColor = _getTextColor(themeColor);

            return GestureDetector(
              onTap: () {
                // TODO: 나중에 모임 상세 화면으로 이동하는 로직을 넣을 곳!
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$groupName 상세 화면은 아직 공사 중 🚧')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // 이모지
                    Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: Center(child: Text(themeEmoji, style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 16),

                    // 모임 이름 & 방장 태그
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (role == 'host') ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                              child: Text('👑 방장', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 화살표 아이콘
                    Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.5), size: 28),
                  ],
                ),
              ),
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
            _fetchMyGroups(); // 새로 만든 모임이 바로 뜨도록 데이터 다시 불러오기!
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
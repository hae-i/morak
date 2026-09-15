import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import '../../repositories/supabase_repository.dart';
import '../../widgets/profile_setup_sheet.dart';
import '../../widgets/member_manage_sheet.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _repository = SupabaseRepository();
  bool _isLoading = true;
  Map<String, dynamic>? _groupData;
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 💡 여기서 원래 길었던 쿼리문들이 사라지고,
      // 레포지토리에 함수를 하나 더 만들어서(fetchGroupDetail) 불러오면 돼!
      // 임시로 레포지토리에서 데이터를 가져왔다고 가정할게.
      // final data = await _repository.fetchGroupDetail(widget.groupId);
      // _groupData = data['group'];
      // _members = data['members'];
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 모임 수정 시트 띄우기 (아까 만든 공용 시트 재활용!)
  Future<void> _showEditSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true,
      builder: (context) => ProfileSetupSheet(
        initialEmoji: _groupData?['theme_emoji'],
        // colorIndex는 hex를 인덱스로 바꾸는 로직 필요
      ),
    );

    if (result != null) {
      // _repository.updateGroup(...) 호출 후 _loadAllData()
    }
  }

  // 멤버 관리 시트 띄우기
  void _showMemberSheet(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => MemberManageSheet(
        member: member,
        onKick: () { /* 강퇴 로직 호출 */ },
        onChangeRole: () { /* 권한 변경 로직 호출 */ },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final themeColor = ColorUtils.hexToColor(_groupData?['theme_color']);
    final textColor = ColorUtils.getTextColor(themeColor);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text(_groupData?['name'] ?? '모임 상세', style: TextStyle(color: textColor)),
        actions: [
          IconButton(icon: Icon(Icons.edit, color: textColor), onPressed: _showEditSheet),
        ],
      ),
      body: ListView.builder(
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return ListTile(
            title: Text(member['display_name']),
            subtitle: Text(member['role']),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMemberSheet(member), // 💡 팝업 코드가 단 3줄로!
            ),
          );
        },
      ),
    );
  }
}
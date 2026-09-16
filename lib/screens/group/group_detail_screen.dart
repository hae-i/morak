import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../../utils/color_utils.dart';
import '../../repositories/group_repository.dart';
import '../../constants/app_constants.dart';
import '../../widgets/profile_setup_sheet.dart';
import 'meetup_create_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  bool _isListView = true;
  bool _isLoading = true;

  late String _currentGroupName;
  String? _currentCoverColor;
  String? _currentEmoji;

  List<Map<String, dynamic>> _meetups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _rankedMembers = [];

  final _repository = GroupRepository();

  @override
  void initState() {
    super.initState();
    _currentGroupName = widget.groupName;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🌟 [리팩토링] 복잡한 계산은 Repository에 맡기고 데이터만 받아옵니다!
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.fetchGroupDetailWithRanking(
        widget.groupId,
      );

      if (mounted) {
        setState(() {
          _currentGroupName = data['group']['name'];
          _currentCoverColor = data['group']['theme_color'];
          _currentEmoji = data['group']['theme_emoji'];
          _meetups = List<Map<String, dynamic>>.from(data['meetups']);
          _members = List<Map<String, dynamic>>.from(data['members']);
          _rankedMembers = List<Map<String, dynamic>>.from(
            data['rankedMembers'],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('상세화면 로드 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('데이터를 불러오지 못했습니다: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditGroupSheet() async {
    final currentColorValue =
        int.tryParse(_currentCoverColor ?? '') ?? Colors.grey[200]!.value;
    int? initialIndex;
    for (int i = 0; i < AppConstants.themeColors.length; i++) {
      if (AppConstants.themeColors[i].value == currentColorValue) {
        initialIndex = i;
        break;
      }
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProfileSetupSheet(
        initialEmoji: _currentEmoji,
        initialColorIndex: initialIndex,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final newColorValue = result['colorIndex'] != null
            ? AppConstants.themeColors[result['colorIndex']].value.toString()
            : Colors.grey[200]!.value.toString();

        await _repository.updateGroup(
          widget.groupId,
          _currentGroupName,
          newColorValue,
          result['emoji'],
        );
        await _loadAllData();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '모임 삭제',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text('정말 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteGroup(widget.groupId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _deleteMeetup(String meetupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteMeetup(meetupId); // 🌟 [리팩토링]
      _loadAllData();
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return '${dt.year}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate;
    }
  }

  String _formatShortDate(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return '${dt.month}.${dt.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = ColorUtils.stringToColor(_currentCoverColor);
    final isDefaultColor = activeColor == Colors.grey[200]!;
    final lastMeetupDate = _meetups.isNotEmpty
        ? _formatDate(_meetups.first['meet_date'])
        : '아직 기록 없음';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      endDrawer: _MemberDrawer(
        groupId: widget.groupId,
        groupName: _currentGroupName,
        members: _members,
        activeColor: activeColor,
        isDefaultColor: isDefaultColor,
        onMembersUpdated: _loadAllData,
        repository: _repository, // 🌟 [리팩토링] Drawer에 레포지토리 전달!
      ),
      appBar: AppBar(
        title: Text(_currentGroupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () async {
              final inviteLink =
                  'morak://invite?groupId=${widget.groupId}&groupName=${widget.groupName}';
              await Clipboard.setData(ClipboardData(text: inviteLink));
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔗 초대 링크가 복사되었습니다!')),
                );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'edit') _showEditGroupSheet();
              if (value == 'delete') _deleteGroup();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('모임 정보 수정')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('모임 삭제하기', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDefaultColor ? Colors.grey[800] : activeColor,
              ),
            )
          : Column(
              children: [
                _buildHeaderInfo(activeColor, isDefaultColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '최근 만남: $lastMeetupDate',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  indicatorColor: isDefaultColor
                      ? Colors.grey[800]
                      : activeColor,
                  labelColor: Colors.grey[800],
                  unselectedLabelColor: Colors.grey[400],
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: '만남 기록'),
                    Tab(text: '랭킹 보드 👑'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMeetupTab(activeColor, isDefaultColor),
                      _buildRankingTab(activeColor, isDefaultColor),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- View 분리 영역 (코드가 훨씬 읽기 쉬워집니다) ---

  Widget _buildHeaderInfo(Color activeColor, bool isDefaultColor) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDefaultColor
                  ? Colors.grey[200]
                  : activeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: (_currentEmoji != null && _currentEmoji!.isNotEmpty)
                  ? Text(_currentEmoji!, style: const TextStyle(fontSize: 36))
                  : Icon(
                      Icons.groups_rounded,
                      color: isDefaultColor ? Colors.grey[400] : activeColor,
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_meetups.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '만남',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_members.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '멤버',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetupTab(Color activeColor, bool isDefaultColor) {
    return RefreshIndicator(
      color: isDefaultColor ? Colors.grey[800] : activeColor,
      onRefresh: _loadAllData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                  color: _isListView
                      ? (isDefaultColor ? Colors.grey[800] : activeColor)
                      : Colors.grey[300],
                  onPressed: () => setState(() => _isListView = true),
                ),
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded),
                  color: !_isListView
                      ? (isDefaultColor ? Colors.grey[800] : activeColor)
                      : Colors.grey[300],
                  onPressed: () => setState(() => _isListView = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: _meetups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAddMeetupCard(
                          activeColor,
                          isDefaultColor,
                          isList: false,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '아직 기록이 없어요!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : (_isListView
                      ? _buildListView(activeColor, isDefaultColor)
                      : _buildAlbumView(activeColor, isDefaultColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingTab(Color activeColor, bool isDefaultColor) {
    return RefreshIndicator(
      color: isDefaultColor ? Colors.grey[800] : activeColor,
      onRefresh: _loadAllData,
      child: _rankedMembers.isEmpty
          ? Center(
              child: Text(
                '멤버가 없어요!',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _rankedMembers.length,
              itemBuilder: (context, index) {
                final member = _rankedMembers[index];
                final rate = member['attendance_rate'] as double;
                final attended = member['attended_count'] as int;
                final isFirstPlace = index == 0 && attended > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isFirstPlace
                            ? const Color(0xFFFFD54F).withOpacity(0.2)
                            : (isDefaultColor
                                  ? Colors.grey[100]
                                  : activeColor.withOpacity(0.1)),
                        child: Text(
                          isFirstPlace ? '👑' : member['display_name'][0],
                          style: TextStyle(
                            fontSize: 16,
                            color: isFirstPlace
                                ? Colors.orange[700]
                                : (isDefaultColor
                                      ? Colors.grey[800]
                                      : activeColor),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          member['display_name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${rate.toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isFirstPlace
                                  ? (isDefaultColor
                                        ? Colors.grey[800]
                                        : activeColor)
                                  : Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$attended / ${_meetups.length}회',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAddMeetupCard(
    Color activeColor,
    bool isDefaultColor, {
    required bool isList,
  }) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetupCreateScreen(groupId: widget.groupId),
          ),
        );
        if (result == true) _loadAllData();
      },
      borderRadius: BorderRadius.circular(isList ? 16 : 12),
      child: Container(
        margin: isList ? const EdgeInsets.only(bottom: 16) : null,
        padding: isList ? const EdgeInsets.all(16) : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDefaultColor
              ? Colors.grey[50]
              : activeColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(isList ? 16 : 12),
          border: Border.all(
            color: isDefaultColor
                ? Colors.grey[300]!
                : activeColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: isList
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: isDefaultColor ? Colors.grey[400] : activeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '만남 기록 추가',
                    style: TextStyle(
                      color: isDefaultColor ? Colors.grey[800] : activeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: isDefaultColor ? Colors.grey[600] : activeColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '기록 추가',
                      style: TextStyle(
                        color: isDefaultColor ? Colors.grey[800] : activeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildListView(Color activeColor, bool isDefaultColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _meetups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0)
          return _buildAddMeetupCard(activeColor, isDefaultColor, isList: true);
        final item = _meetups[index - 1];
        final title = [
          item['location'] ?? '',
          item['menu'] ?? '',
        ].where((s) => s.toString().isNotEmpty).join(' · ');
        final attendeeCount = (item['attendances'] as List?)?.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDefaultColor
                      ? Colors.grey[100]
                      : activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: isDefaultColor ? Colors.grey[400] : activeColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(item['meet_date']),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.isNotEmpty ? title : '기록 내용 없음',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (attendeeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDefaultColor
                              ? Colors.grey[100]
                              : activeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '👥 참석 $attendeeCount명',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
                onSelected: (v) async {
                  if (v == 'edit') {
                    final r = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeetupCreateScreen(
                          groupId: widget.groupId,
                          initialMeetup: item,
                        ),
                      ),
                    );
                    if (r == true) _loadAllData();
                  } else if (v == 'delete')
                    _deleteMeetup(item['id']);
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제하기', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumView(Color activeColor, bool isDefaultColor) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _meetups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0)
          return _buildAddMeetupCard(
            activeColor,
            isDefaultColor,
            isList: false,
          );
        final item = _meetups[index - 1];
        return InkWell(
          onLongPress: () => _deleteMeetup(item['id']),
          child: Container(
            decoration: BoxDecoration(
              color: isDefaultColor
                  ? Colors.grey[200]
                  : activeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(8),
            child: Text(
              _formatShortDate(item['meet_date']),
              style: TextStyle(
                color: isDefaultColor ? Colors.grey[800] : activeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

// 🌟 사이드바 위젯
class _MemberDrawer extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<Map<String, dynamic>> members;
  final VoidCallback onMembersUpdated;
  final Color activeColor;
  final bool isDefaultColor;
  final GroupRepository repository; // 🌟 [리팩토링] Repository 의존성 주입

  const _MemberDrawer({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.onMembersUpdated,
    required this.activeColor,
    required this.isDefaultColor,
    required this.repository,
  });

  @override
  State<_MemberDrawer> createState() => _MemberDrawerState();
}

class _MemberDrawerState extends State<_MemberDrawer> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteLink() async {
    final inviteLink =
        'morak://invite?groupId=${widget.groupId}&groupName=${widget.groupName}';
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('🔗 초대 링크가 복사되었습니다!')));
    }
  }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.addMember(
        widget.groupId,
        _nameController.text.trim(),
      ); // 🌟 [리팩토링]
      _nameController.clear();
      widget.onMembersUpdated();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('${member['display_name']} 님을 정말 내보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('내보내기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.removeMember(member['id']); // 🌟 [리팩토링]
        widget.onMembersUpdated();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('에러: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 핵심: 현재 로그인한 유저 ID 가져오기
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Drawer(
      backgroundColor: Colors.grey[50],
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Text(
                    '멤버 관리 👥',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton.icon(
                onPressed: _copyInviteLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDefaultColor
                      ? Colors.grey[800]
                      : widget.activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  '초대링크 복사하기',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            Expanded(
              child: widget.members.isEmpty
                  ? const Center(child: Text('멤버가 없어요.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: widget.members.length,
                      itemBuilder: (context, index) {
                        final member = widget.members[index];
                        final isHost = member['role'] == 'host';

                        // 🌟 핵심: 이 리스트 항목이 '나'인지 판별!
                        final isMe =
                            currentUserId != null &&
                            member['user_id'] == currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              isHost ? '👑' : member['display_name'][0],
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.bold,
                                fontSize: isHost ? 14 : 16,
                              ),
                            ),
                          ),
                          title: Text(
                            member['display_name'] +
                                (isMe ? ' (나)' : ''), // (나) 표시 추가!
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          // 🌟 핵심: 나 자신이면 빈 공간(SizedBox.shrink)을 주고, 아니면 휴지통 아이콘을 줍니다!
                          trailing: isMe
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _removeMember(member),
                                ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 12
                    : 24,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '수동으로 멤버 추가',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addMember(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSaving
                      ? const CircularProgressIndicator(color: Colors.grey)
                      : IconButton(
                          onPressed: _addMember,
                          icon: const Icon(Icons.person_add_rounded),
                          color: Colors.grey[800],
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

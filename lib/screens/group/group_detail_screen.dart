import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late TabController _tabController;
  bool _isListView = true;
  bool _isLoading = true;

  late String _currentGroupName;
  String? _currentCoverColor;
  String? _currentEmoji;

  List<Map<String, dynamic>> _meetups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _rankedMembers = [];

  // 🌟 리팩토링 된 레포지토리 사용!
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final groupRes = await client
          .from('groups')
          .select()
          .eq('id', widget.groupId)
          .single();
      final meetupsRes = await client
          .from('meetups')
          .select('*, attendances(member_id)')
          .eq('group_id', widget.groupId)
          .order('meet_date', ascending: false);

      // 🌟 핵심 수정: created_at -> joined_at 으로 변경!
      final membersRes = await client
          .from('group_members')
          .select()
          .eq('group_id', widget.groupId)
          .order('joined_at', ascending: true);

      int totalMeetups = meetupsRes.length;
      Map<String, int> attendanceCounts = {};
      for (var meetup in meetupsRes) {
        for (var att in meetup['attendances'] as List? ?? []) {
          String mId = att['member_id'].toString();
          attendanceCounts[mId] = (attendanceCounts[mId] ?? 0) + 1;
        }
      }

      List<Map<String, dynamic>> ranked = [];
      for (var m in membersRes) {
        String mId = m['id'].toString();
        int attended = attendanceCounts[mId] ?? 0;
        ranked.add({
          ...m,
          'attended_count': attended,
          'attendance_rate': totalMeetups > 0
              ? (attended / totalMeetups) * 100
              : 0.0,
        });
      }
      ranked.sort((a, b) {
        int r = b['attendance_rate'].compareTo(a['attendance_rate']);
        return r != 0 ? r : a['display_name'].compareTo(b['display_name']);
      });

      if (mounted) {
        setState(() {
          _currentGroupName = groupRes['name'];
          _currentCoverColor = groupRes['theme_color'];
          _currentEmoji = groupRes['theme_emoji'];
          _meetups = List<Map<String, dynamic>>.from(meetupsRes);
          _members = List<Map<String, dynamic>>.from(membersRes);
          _rankedMembers = ranked;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 🌟 숨겨진 에러를 밖으로 꺼내서 스낵바로 보여줍니다!
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
        final newEmoji = result['emoji'];
        final newColorIndex = result['colorIndex'];
        final newColorValue = newColorIndex != null
            ? AppConstants.themeColors[newColorIndex].value.toString()
            : Colors.grey[200]!.value.toString();

        await _repository.updateGroup(
          widget.groupId,
          _currentGroupName,
          newColorValue,
          newEmoji,
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
      await _repository.deleteGroup(widget.groupId); // 레포지토리 사용!
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
      await Supabase.instance.client
          .from('meetups')
          .delete()
          .eq('id', meetupId);
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
    // 🌟 리팩토링된 ColorUtils 활용!
    final activeColor = ColorUtils.stringToColor(_currentCoverColor);
    final isDefaultColor = activeColor == Colors.grey[200]!;
    final lastMeetupDate = _meetups.isNotEmpty
        ? _formatDate(_meetups.first['meet_date'])
        : '아직 기록 없음';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_currentGroupName),
        actions: [
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
                Padding(
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
                          child:
                              (_currentEmoji != null &&
                                  _currentEmoji!.isNotEmpty)
                              ? Text(
                                  _currentEmoji!,
                                  style: const TextStyle(fontSize: 36),
                                )
                              : Icon(
                                  Icons.groups_rounded,
                                  color: isDefaultColor
                                      ? Colors.grey[400]
                                      : activeColor,
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Column(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                      RefreshIndicator(
                        color: isDefaultColor ? Colors.grey[800] : activeColor,
                        onRefresh: _loadAllData,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 16.0,
                                top: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.format_list_bulleted_rounded,
                                    ),
                                    color: _isListView
                                        ? (isDefaultColor
                                              ? Colors.grey[800]
                                              : activeColor)
                                        : Colors.grey[300],
                                    onPressed: () =>
                                        setState(() => _isListView = true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.grid_view_rounded),
                                    color: !_isListView
                                        ? (isDefaultColor
                                              ? Colors.grey[800]
                                              : activeColor)
                                        : Colors.grey[300],
                                    onPressed: () =>
                                        setState(() => _isListView = false),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _meetups.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.edit_calendar_rounded,
                                            size: 56,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '아직 기록이 없어요!',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : (_isListView
                                        ? _buildListView(
                                            activeColor,
                                            isDefaultColor,
                                          )
                                        : _buildAlbumView(
                                            activeColor,
                                            isDefaultColor,
                                          )),
                            ),
                          ],
                        ),
                      ),
                      RefreshIndicator(
                        color: isDefaultColor ? Colors.grey[800] : activeColor,
                        onRefresh: _loadAllData,
                        child: _rankedMembers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_alt_outlined,
                                      size: 56,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '멤버가 없어요!',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                itemCount: _rankedMembers.length,
                                itemBuilder: (context, index) {
                                  final member = _rankedMembers[index];
                                  final rate =
                                      member['attendance_rate'] as double;
                                  final attended =
                                      member['attended_count'] as int;
                                  final isFirstPlace =
                                      index == 0 && attended > 0;

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
                                              ? const Color(0xFFFFD54F)
                                                    .withOpacity(0.2)
                                              : (isDefaultColor
                                                    ? Colors.grey[100]
                                                    : activeColor.withOpacity(
                                                        0.1,
                                                      )),
                                          child: Text(
                                            isFirstPlace
                                                ? '👑'
                                                : member['display_name'][0],
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: isDefaultColor ? Colors.grey[800] : activeColor,
              elevation: 4,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MeetupCreateScreen(groupId: widget.groupId),
                  ),
                );
                if (result == true) _loadAllData();
              },
              icon: Icon(
                Icons.edit_rounded,
                color: isDefaultColor
                    ? Colors.white
                    : ColorUtils.getTextColor(activeColor),
              ),
              label: Text(
                '기록 남기기',
                style: TextStyle(
                  color: isDefaultColor
                      ? Colors.white
                      : ColorUtils.getTextColor(activeColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : FloatingActionButton.extended(
              backgroundColor: Colors.grey[800],
              elevation: 4,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _MemberManageSheet(
                    groupId: widget.groupId,
                    members: _members,
                    onMembersUpdated: _loadAllData,
                  ),
                );
              },
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text(
                '멤버 영입',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildListView(Color activeColor, bool isDefaultColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _meetups.length,
      itemBuilder: (context, index) {
        final item = _meetups[index];
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
      itemCount: _meetups.length,
      itemBuilder: (context, index) {
        final item = _meetups[index];
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

class _MemberManageSheet extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final VoidCallback onMembersUpdated;

  const _MemberManageSheet({
    required this.groupId,
    required this.members,
    required this.onMembersUpdated,
  });

  @override
  State<_MemberManageSheet> createState() => _MemberManageSheetState();
}

class _MemberManageSheetState extends State<_MemberManageSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('group_members').insert({
        'group_id': widget.groupId,
        'display_name': _nameController.text.trim(),
      });
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

  Future<void> _removeMember(String id) async {
    try {
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('id', id);
      widget.onMembersUpdated();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('에러: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset > 0 ? bottomInset : 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '멤버 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '새로운 멤버 이름',
                      filled: true,
                      fillColor: Colors.grey[100],
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
          const SizedBox(height: 16),
          const Divider(),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
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
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          child: Text(
                            member['display_name'][0],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          member['display_name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () => _removeMember(member['id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

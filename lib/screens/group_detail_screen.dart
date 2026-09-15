import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'meetup_create_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isListView = true;
  bool _isLoading = true;

  late String _currentGroupName;
  String? _currentCoverColor;
  String? _currentEmoji; // 👈 현재 모임 이모지 상태

  List<Map<String, dynamic>> _meetups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _rankedMembers = [];

  final List<Color> _themeColors = const [
    Color(0xFFFF8A80), Color(0xFFFFCC80), Color(0xFFFFF59D),
    Color(0xFFA5D6A7), Color(0xFF81D4FA), Color(0xFFCE93D8),
  ];
  final List<String> _emojis = ['🍻', '🥩', '⚾️', '✈️', '💻', '🏕️', '☕️', '🎤', '🏀', '🎂', '🐶', '📚'];

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

  Color _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey[200]!;

    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _getTextColor(Color bg) => bg.computeLuminance() > 0.6 ? Colors.grey[800]! : Colors.white;

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final groupRes = await client.from('groups').select().eq('id', widget.groupId).single();
      final meetupsRes = await client.from('meetups').select('*, attendances(member_id)').eq('group_id', widget.groupId).order('meet_date', ascending: false);
      final membersRes = await client.from('group_members').select().eq('group_id', widget.groupId).order('created_at', ascending: true);

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
        ranked.add({...m, 'attended_count': attended, 'attendance_rate': totalMeetups > 0 ? (attended / totalMeetups) * 100 : 0.0});
      }
      ranked.sort((a, b) {
        int r = b['attendance_rate'].compareTo(a['attendance_rate']);
        return r != 0 ? r : a['display_name'].compareTo(b['display_name']);
      });

      if (mounted) {
        setState(() {
          _currentGroupName = groupRes['name'];
          _currentCoverColor = groupRes['cover_color'];
          _currentEmoji = groupRes['profile_emoji']; // DB에서 이모지 로드!
          _meetups = List<Map<String, dynamic>>.from(meetupsRes);
          _members = List<Map<String, dynamic>>.from(membersRes);
          _rankedMembers = ranked;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showEditGroupSheet() {
    final TextEditingController nameController = TextEditingController(text: _currentGroupName);
    String? currentHex = _currentCoverColor;
    String? currentEmoji = _currentEmoji;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final activeColor = _hexToColor(currentHex);
            // 💡 DB에서 가져온 빈 값("")도 안전하게 기본색으로 처리!
            final isDefaultColor = currentHex == null || currentHex!.isEmpty;
            final isDefaultEmoji = currentEmoji == null || currentEmoji!.isEmpty;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 24, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  const Text('모임 정보 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (context) => StatefulBuilder(
                          builder: (context, setInnerState) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('이모지 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 12, runSpacing: 12, children: [
                                    GestureDetector(
                                      onTap: () { setInnerState(() => currentEmoji = null); setSheetState(() {}); },
                                      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (currentEmoji == null || currentEmoji!.isEmpty) ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.do_not_disturb_alt_rounded, color: Colors.grey, size: 28)),
                                    ),
                                    ..._emojis.map((emoji) => GestureDetector(
                                      onTap: () { setInnerState(() => currentEmoji = emoji); setSheetState(() {}); },
                                      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: currentEmoji == emoji ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: Text(emoji, style: const TextStyle(fontSize: 28))),
                                    )),
                                  ]),
                                  const SizedBox(height: 32),
                                  const Text('배경 색상', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 16, runSpacing: 16, children: [
                                    GestureDetector(
                                      onTap: () { setInnerState(() => currentHex = null); setSheetState(() {}); },
                                      child: Container(
                                          width: 50, height: 50,
                                          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: (currentHex == null || currentHex!.isEmpty) ? Border.all(color: Colors.grey[800]!, width: 3) : null),
                                          // 💡 체크마크 색상 진하게 고정!
                                          child: (currentHex == null || currentHex!.isEmpty) ? Icon(Icons.check_rounded, color: Colors.grey[800]) : null
                                      ),
                                    ),
                                    ..._themeColors.map((color) {
                                      final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                                      return GestureDetector(
                                        onTap: () { setInnerState(() => currentHex = hex); setSheetState(() {}); },
                                        child: Container(width: 50, height: 50, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: currentHex == hex ? Border.all(color: Colors.grey[800]!, width: 3) : null), child: currentHex == hex ? Icon(Icons.check_rounded, color: _getTextColor(color)) : null),
                                      );
                                    }),
                                  ]),
                                  const SizedBox(height: 32),
                                  SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('적용', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                          child: Center(
                              child: !isDefaultEmoji
                                  ? Text(currentEmoji!, style: const TextStyle(fontSize: 44))
                                  : Icon(Icons.groups_rounded, color: isDefaultColor ? Colors.grey[400] : _getTextColor(activeColor), size: 44)
                          ),
                        ),
                        Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(controller: nameController, maxLength: 30, decoration: InputDecoration(hintText: '모임 이름', filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDefaultColor ? Colors.grey[400]! : activeColor, width: 1.5)))),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;

                        await Supabase.instance.client.from('groups').update({
                          'name': newName,
                          'cover_color': currentHex,
                          'profile_emoji': currentEmoji,
                        }).eq('id', widget.groupId);

                        if (mounted) { Navigator.pop(context); _loadAllData(); }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: isDefaultColor ? Colors.grey[800] : activeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: Text('수정 완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDefaultColor ? Colors.white : _getTextColor(activeColor))),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('모임 삭제', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), content: const Text('정말 삭제할까요?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) { await Supabase.instance.client.from('groups').delete().eq('id', widget.groupId); if (mounted) Navigator.pop(context, true); }
  }

  Future<void> _deleteMeetup(String meetupId) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('기록 삭제'), content: const Text('삭제할까요?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) { await Supabase.instance.client.from('meetups').delete().eq('id', meetupId); _loadAllData(); }
  }

  String _formatDate(String? rawDate) { if (rawDate == null) return ''; try { final dt = DateTime.parse(rawDate); return '${dt.year}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}'; } catch (_) { return rawDate; } }
  String _formatShortDate(String? rawDate) { if (rawDate == null) return ''; try { final dt = DateTime.parse(rawDate); return '${dt.month}.${dt.day}'; } catch (_) { return ''; } }

  @override
  Widget build(BuildContext context) {
    final activeColor = _hexToColor(_currentCoverColor);
    final isDefaultColor = _currentCoverColor == null;
    final lastMeetupDate = _meetups.isNotEmpty ? _formatDate(_meetups.first['meet_date']) : '아직 기록 없음';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(_currentGroupName), actions: [PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded), onSelected: (value) { if (value == 'edit') _showEditGroupSheet(); if (value == 'delete') _deleteGroup(); }, itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('모임 정보 수정')), const PopupMenuItem(value: 'delete', child: Text('모임 삭제하기', style: TextStyle(color: Colors.red)))])]),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: isDefaultColor ? Colors.grey[800] : activeColor))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: isDefaultColor ? Colors.grey[200] : activeColor.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(child: _currentEmoji != null ? Text(_currentEmoji!, style: const TextStyle(fontSize: 36)) : Icon(Icons.groups_rounded, color: isDefaultColor ? Colors.grey[400] : activeColor, size: 36)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [Text('${_meetups.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('만남', style: TextStyle(fontSize: 13, color: Colors.grey[600]))]),
                      Column(children: [Text('${_members.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('멤버', style: TextStyle(fontSize: 13, color: Colors.grey[600]))]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Align(alignment: Alignment.centerLeft, child: Text('최근 만남: $lastMeetupDate', style: TextStyle(fontSize: 13, color: Colors.grey[500])))),
          const SizedBox(height: 16),

          // 💡 탭바 글씨색은 무조건 진하게(Grey800) 고정해서 노란색이어도 잘 보이게!
          TabBar(
            controller: _tabController, indicatorColor: isDefaultColor ? Colors.grey[800] : activeColor, labelColor: Colors.grey[800], unselectedLabelColor: Colors.grey[400], labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [Tab(text: '만남 기록'), Tab(text: '랭킹 보드 👑')],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  color: isDefaultColor ? Colors.grey[800] : activeColor, onRefresh: _loadAllData,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(icon: const Icon(Icons.format_list_bulleted_rounded), color: _isListView ? (isDefaultColor ? Colors.grey[800] : activeColor) : Colors.grey[300], onPressed: () => setState(() => _isListView = true)),
                            IconButton(icon: const Icon(Icons.grid_view_rounded), color: !_isListView ? (isDefaultColor ? Colors.grey[800] : activeColor) : Colors.grey[300], onPressed: () => setState(() => _isListView = false)),
                          ],
                        ),
                      ),
                      Expanded(child: _meetups.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit_calendar_rounded, size: 56, color: Colors.grey[300]), const SizedBox(height: 12), Text('아직 기록이 없어요!', style: TextStyle(color: Colors.grey[500]))])) : (_isListView ? _buildListView(activeColor, isDefaultColor) : _buildAlbumView(activeColor, isDefaultColor))),
                    ],
                  ),
                ),
                RefreshIndicator(
                  color: isDefaultColor ? Colors.grey[800] : activeColor, onRefresh: _loadAllData,
                  child: _rankedMembers.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_alt_outlined, size: 56, color: Colors.grey[300]), const SizedBox(height: 12), Text('멤버가 없어요!', style: TextStyle(color: Colors.grey[500]))]))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _rankedMembers.length,
                    itemBuilder: (context, index) {
                      final member = _rankedMembers[index];
                      final rate = member['attendance_rate'] as double;
                      final attended = member['attended_count'] as int;
                      final isFirstPlace = index == 0 && attended > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: isFirstPlace ? const Color(0xFFFFD54F).withOpacity(0.2) : (isDefaultColor ? Colors.grey[100] : activeColor.withOpacity(0.1)), child: Text(isFirstPlace ? '👑' : member['display_name'][0], style: TextStyle(fontSize: 16, color: isFirstPlace ? Colors.orange[700] : (isDefaultColor ? Colors.grey[800] : activeColor), fontWeight: FontWeight.bold))),
                            const SizedBox(width: 16),
                            Expanded(child: Text(member['display_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${rate.toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isFirstPlace ? (isDefaultColor ? Colors.grey[800] : activeColor) : Colors.grey[700])), Text('$attended / ${_meetups.length}회', style: TextStyle(fontSize: 12, color: Colors.grey[400]))]),
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
          ? FloatingActionButton.extended(backgroundColor: isDefaultColor ? Colors.grey[800] : activeColor, elevation: 4, onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MeetupCreateScreen(groupId: widget.groupId))); if (result == true) _loadAllData(); }, icon: Icon(Icons.edit_rounded, color: isDefaultColor ? Colors.white : _getTextColor(activeColor)), label: Text('기록 남기기', style: TextStyle(color: isDefaultColor ? Colors.white : _getTextColor(activeColor), fontWeight: FontWeight.bold)))
          : FloatingActionButton.extended(backgroundColor: Colors.grey[800], elevation: 4, onPressed: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _MemberManageSheet(groupId: widget.groupId, members: _members, onMembersUpdated: _loadAllData)); }, icon: const Icon(Icons.person_add_rounded, color: Colors.white), label: const Text('멤버 영입', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildListView(Color activeColor, bool isDefaultColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), itemCount: _meetups.length,
      itemBuilder: (context, index) {
        final item = _meetups[index];
        final title = [item['location'] ?? '', item['menu'] ?? ''].where((s) => s.toString().isNotEmpty).join(' · ');
        final attendeeCount = (item['attendances'] as List?)?.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Row(
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: isDefaultColor ? Colors.grey[100] : activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.restaurant_rounded, color: isDefaultColor ? Colors.grey[400] : activeColor)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDate(item['meet_date']), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title.isNotEmpty ? title : '기록 내용 없음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8),
                    if (attendeeCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDefaultColor ? Colors.grey[100] : activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('👥 참석 $attendeeCount명', style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20), onSelected: (v) async { if (v == 'edit') { final r = await Navigator.push(context, MaterialPageRoute(builder: (context) => MeetupCreateScreen(groupId: widget.groupId, initialMeetup: item))); if (r == true) _loadAllData(); } else if (v == 'delete') _deleteMeetup(item['id']); }, itemBuilder: (c) => [const PopupMenuItem(value: 'edit', child: Text('수정하기')), const PopupMenuItem(value: 'delete', child: Text('삭제하기', style: TextStyle(color: Colors.red)))]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumView(Color activeColor, bool isDefaultColor) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: _meetups.length,
      itemBuilder: (context, index) {
        final item = _meetups[index];
        return InkWell(onLongPress: () => _deleteMeetup(item['id']), child: Container(decoration: BoxDecoration(color: isDefaultColor ? Colors.grey[200] : activeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), alignment: Alignment.bottomRight, padding: const EdgeInsets.all(8), child: Text(_formatShortDate(item['meet_date']), style: TextStyle(color: isDefaultColor ? Colors.grey[800] : activeColor, fontSize: 12, fontWeight: FontWeight.bold))));
      },
    );
  }
}

class _MemberManageSheet extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final VoidCallback onMembersUpdated;
  const _MemberManageSheet({required this.groupId, required this.members, required this.onMembersUpdated});
  @override State<_MemberManageSheet> createState() => _MemberManageSheetState();
}

class _MemberManageSheetState extends State<_MemberManageSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  @override void dispose() { _nameController.dispose(); super.dispose(); }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try { await Supabase.instance.client.from('group_members').insert({'group_id': widget.groupId, 'display_name': _nameController.text.trim()}); _nameController.clear(); widget.onMembersUpdated(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 실패! 에러: $e'))); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }
  Future<void> _removeMember(String memberId) async {
    try { await Supabase.instance.client.from('group_members').delete().eq('id', memberId); widget.onMembersUpdated(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e'))); }
  }

  @override Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 24),
          const Text('멤버 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _nameController, decoration: InputDecoration(hintText: '새로운 멤버 이름', filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onSubmitted: (_) => _addMember())), const SizedBox(width: 12),
                _isSaving ? const CircularProgressIndicator(color: Color(0xFFFF8A80)) : IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add_rounded), color: const Color(0xFFFF8A80), style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF8A80).withOpacity(0.1))),
              ],
            ),
          ),
          const SizedBox(height: 16), const Divider(),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: widget.members.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('등록된 멤버가 없어요.', style: TextStyle(color: Colors.grey)))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: widget.members.length, itemBuilder: (context, index) { final member = widget.members[index]; return ListTile(leading: CircleAvatar(backgroundColor: Colors.grey[100], child: Text(member['display_name'][0], style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))), title: Text(member['display_name'], style: const TextStyle(fontWeight: FontWeight.w600)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.grey), onPressed: () => _removeMember(member['id']))); }),
          ),
        ],
      ),
    );
  }
}
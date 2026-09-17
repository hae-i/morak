import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/color_utils.dart';
import '../../repositories/group_repository.dart';
import '../../constants/app_constants.dart';
import '../../widgets/profile_setup_sheet.dart';
import 'meetup_create_screen.dart';
import 'meetup_detail_screen.dart';
import 'group_info_screen.dart';
import 'photo_viewer_screen.dart';

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
  String? _currentCoverImageUrl;
  String? _currentLogoImageUrl;

  List<Map<String, dynamic>> _meetups = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _rankedMembers = [];
  List<String> _allAlbumPhotos = [];

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
      final data = await _repository.fetchGroupDetailWithRanking(
        widget.groupId,
      );
      if (mounted) {
        setState(() {
          _currentGroupName = data['group']['name'];
          _currentCoverColor = data['group']['theme_color'];
          _currentEmoji = data['group']['theme_emoji'];
          _currentCoverImageUrl = data['group']['cover_image_url'];
          _currentLogoImageUrl = data['group']['logo_image_url'];
          _meetups = List<Map<String, dynamic>>.from(data['meetups']);
          _members = List<Map<String, dynamic>>.from(data['members']);
          _rankedMembers = List<Map<String, dynamic>>.from(
            data['rankedMembers'],
          );
          _allAlbumPhotos.clear();
          for (var meetup in _meetups) {
            final photos = meetup['photos'] as List<dynamic>? ?? [];
            _allAlbumPhotos.addAll(photos.map((e) => e.toString()));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('에러: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showBeautifulDialog(
    String title,
    String content,
    String confirmText,
    Color confirmColor,
    IconData icon,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: confirmColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey[100],
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMyProfileEditSheet(Map<String, dynamic> memberData) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupProfileEditSheet(
        memberData: memberData,
        repository: _repository,
        onUpdated: _loadAllData,
      ),
    );
  }

  void _showMemberProfileSheet(Map<String, dynamic> member) {
    final rankedData = _rankedMembers.firstWhere(
      (m) => m['id'] == member['id'],
      orElse: () => member,
    );
    final int attended = rankedData['attended_count'] ?? 0;
    final double rate = rankedData['attendance_rate'] ?? 0.0;
    final bool isHost = member['role'] == 'host';
    final String? profileImageUrl = member['profile_image_url'];
    final bool isMe =
        member['user_id'] ==
        (Supabase.instance.client.auth.currentUser?.id ?? '');
    final bool isBirthdayPublic = member['is_birthday_public'] ?? true;
    final String? birthday = member['users']?['birthday'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 24.0,
            top: 12,
            left: 24,
            right: 24,
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
              const SizedBox(height: 16),
              if (isMe)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.settings_rounded, color: Colors.grey[600]),
                    onPressed: () => _openMyProfileEditSheet(member),
                    tooltip: '프로필 수정',
                  ),
                )
              else
                const SizedBox(height: 48),
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isHost)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Text(
                                  '👑',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                member['display_name'] + (isMe ? ' (나)' : ''),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (isBirthdayPublic && birthday != null)
                              ? '🎂 생일: ${birthday.replaceAll('-', '. ')}'
                              : (isHost ? '모임 방장' : '일반 멤버'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          '참여한 만남',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$attended회',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.black12),
                    Column(
                      children: [
                        const Text(
                          '참석률',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${rate.toInt()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF8A80),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate.toString());
      return '${dt.year}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = ColorUtils.stringToColor(_currentCoverColor);
    final isDefaultColor = activeColor == Colors.grey[200]!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey[50],
        endDrawer: _MemberDrawer(
          groupId: widget.groupId,
          groupName: _currentGroupName,
          members: _rankedMembers,
          activeColor: activeColor,
          isDefaultColor: isDefaultColor,
          onMembersUpdated: _loadAllData,
          repository: _repository,
          showDialogFunc: _showBeautifulDialog,
          onMemberTap: _showMemberProfileSheet,
        ),
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[800]),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            _currentGroupName,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share_rounded, color: Colors.grey[800]),
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
                      Tab(text: '추억 앨범 📸'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMeetupTab(activeColor, isDefaultColor),
                        _buildAlbumTab(activeColor, isDefaultColor),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderInfo(Color activeColor, bool isDefaultColor) {
    final bool hasCover =
        _currentCoverImageUrl != null && _currentCoverImageUrl!.isNotEmpty;
    final bool hasLogo =
        _currentLogoImageUrl != null && _currentLogoImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: hasCover
              ? Colors.black
              : (isDefaultColor
                    ? Colors.grey[200]
                    : activeColor.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(24),
          image: hasCover
              ? DecorationImage(
                  image: NetworkImage(_currentCoverImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: hasCover
                ? const LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final groupData = {
                    'id': widget.groupId,
                    'name': _currentGroupName,
                    'theme_color': _currentCoverColor,
                    'theme_emoji': _currentEmoji,
                    'cover_image_url': _currentCoverImageUrl,
                    'logo_image_url': _currentLogoImageUrl,
                  };
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupInfoScreen(
                        groupData: groupData,
                        repository: _repository,
                      ),
                    ),
                  );
                  if (result == 'deleted') {
                    if (mounted) Navigator.pop(context, true);
                  } else if (result == 'updated') {
                    _loadAllData();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: hasCover ? Colors.white24 : Colors.white54,
                    shape: BoxShape.circle,
                    image: hasLogo
                        ? DecorationImage(
                            image: NetworkImage(_currentLogoImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasLogo
                      ? null
                      : Center(
                          child:
                              (_currentEmoji != null &&
                                  _currentEmoji!.isNotEmpty)
                              ? Text(
                                  _currentEmoji!,
                                  style: const TextStyle(fontSize: 32),
                                )
                              : Icon(
                                  Icons.groups_rounded,
                                  color: hasCover
                                      ? Colors.white
                                      : (isDefaultColor
                                            ? Colors.grey[400]
                                            : activeColor),
                                  size: 32,
                                ),
                        ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _tabController.animateTo(0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_meetups.length}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: hasCover ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '만남 기록',
                            style: TextStyle(
                              fontSize: 13,
                              color: hasCover
                                  ? Colors.white70
                                  : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: hasCover ? Colors.white24 : Colors.black12,
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_members.length}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: hasCover ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '모임 멤버',
                            style: TextStyle(
                              fontSize: 13,
                              color: hasCover
                                  ? Colors.white70
                                  : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetupTab(Color activeColor, bool isDefaultColor) {
    return RefreshIndicator(
      color: isDefaultColor ? Colors.grey[800] : activeColor,
      onRefresh: _loadAllData,
      child: Column(
        children: [
          Expanded(
            child: _meetups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 남겨진 기록이 없어요.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColor,
                            foregroundColor: ColorUtils.getTextColor(
                              activeColor,
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            '첫 만남 기록하기',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildListView(activeColor, isDefaultColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumTab(Color activeColor, bool isDefaultColor) {
    List<Map<String, dynamic>> albumPhotos = [];
    for (var meetup in _meetups) {
      final photos = meetup['photos'] as List<dynamic>? ?? [];
      for (var p in photos) {
        albumPhotos.add({'url': p.toString(), 'meetup': meetup});
      }
    }
    final imageUrls = albumPhotos
        .map((e) => e['url'] as String)
        .toList(); // 전체 URL 리스트 추출

    return RefreshIndicator(
      color: isDefaultColor ? Colors.grey[800] : activeColor,
      onRefresh: _loadAllData,
      child: albumPhotos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 등록된 사진이 없어요.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: albumPhotos.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoViewerScreen(
                        imageUrls: imageUrls,
                        initialIndex: index,
                        meetup: albumPhotos[index]['meetup'],
                        groupMembers: _members,
                        activeColor: activeColor,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrls[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAddMeetupCard(Color activeColor, bool isDefaultColor) {
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDefaultColor
              ? Colors.grey[200]
              : activeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_rounded,
              color: isDefaultColor ? Colors.grey[600] : activeColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '새로운 만남 기록하기',
              style: TextStyle(
                color: isDefaultColor ? Colors.grey[800] : activeColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(Color activeColor, bool isDefaultColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _meetups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildAddMeetupCard(activeColor, isDefaultColor);
        final item = _meetups[index - 1];
        final title = item['title']?.toString().isNotEmpty == true
            ? item['title']
            : '제목 없는 만남';
        final subText = [
          item['location'] ?? '',
          item['menu'] ?? '',
        ].where((s) => s.toString().isNotEmpty).join(' · ');
        final attendeeCount = (item['attendances'] as List?)?.length ?? 0;
        final photos = item['photos'] as List<dynamic>? ?? [];
        final hasPhoto = photos.isNotEmpty;
        final bgImageUrl = hasPhoto ? photos.first.toString() : null;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeetupDetailScreen(
                  meetup: item,
                  groupMembers: _members,
                  activeColor: activeColor,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 130,
            decoration: BoxDecoration(
              color: hasPhoto ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(bgImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: hasPhoto
                    ? const LinearGradient(
                        colors: [Colors.black87, Colors.black26],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!hasPhoto)
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
                  if (!hasPhoto) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDate(item['meet_date']),
                          style: TextStyle(
                            color: hasPhoto ? Colors.white70 : Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasPhoto ? Colors.white : Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subText,
                              style: TextStyle(
                                fontSize: 13,
                                color: hasPhoto
                                    ? Colors.white70
                                    : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (attendeeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: hasPhoto
                                  ? Colors.white24
                                  : (isDefaultColor
                                        ? Colors.grey[100]
                                        : activeColor.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '👥 참석 $attendeeCount명',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasPhoto
                                    ? Colors.white
                                    : Colors.grey[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 🌟 [개조] 모임 정보 수정 시트 (카톡 액션 메뉴 적용)
class _GroupEditSheet extends StatefulWidget {
  final String groupId, initialName;
  final String? initialEmoji, initialColor, initialCoverUrl, initialLogoUrl;
  final GroupRepository repository;
  final VoidCallback onUpdated;
  const _GroupEditSheet({
    required this.groupId,
    required this.initialName,
    this.initialEmoji,
    this.initialColor,
    this.initialCoverUrl,
    this.initialLogoUrl,
    required this.repository,
    required this.onUpdated,
  });
  @override
  State<_GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends State<_GroupEditSheet> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _localCover;
  XFile? _localLogo;
  String? _selectedEmoji;
  int? _selectedColorIndex;
  bool _isSaving = false;
  String? _existingCoverUrl;
  String? _existingLogoUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedEmoji = widget.initialEmoji;
    _existingCoverUrl = widget.initialCoverUrl;
    _existingLogoUrl = widget.initialLogoUrl;
    if (widget.initialColor != null) {
      final val = int.tryParse(widget.initialColor!) ?? Colors.grey[200]!.value;
      for (int i = 0; i < AppConstants.themeColors.length; i++) {
        if (AppConstants.themeColors[i].value == val) {
          _selectedColorIndex = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showImageActionMenu({
    required VoidCallback onPick,
    required VoidCallback onDelete,
    required bool hasImage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.black87,
                ),
                title: const Text(
                  '앨범에서 사진 선택',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPick();
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    '사진 삭제하기',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(bool isCover) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked != null)
      setState(() {
        if (isCover)
          _localCover = picked;
        else
          _localLogo = picked;
      });
  }

  Future<void> _showColorPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProfileSetupSheet(
        initialEmoji: _selectedEmoji,
        initialColorIndex: _selectedColorIndex,
      ),
    );
    if (result != null) {
      setState(() {
        if (result['image'] != null) {
          _localLogo = result['image'];
          _selectedEmoji = null;
        } else {
          _selectedEmoji = result['emoji'];
          _selectedColorIndex = result['colorIndex'];
          _localLogo = null;
          _existingLogoUrl = null;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final colorStr = _selectedColorIndex != null
          ? '#${AppConstants.themeColors[_selectedColorIndex!].value.toRadixString(16).substring(2).toUpperCase()}'
          : null;
      await widget.repository.updateGroup(
        widget.groupId,
        name,
        colorStr,
        _selectedEmoji,
        _localCover,
        _existingCoverUrl,
        _localLogo,
        _existingLogoUrl,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 40,
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
            '모임 정보 수정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => _showImageActionMenu(
              onPick: () => _pickImage(true),
              onDelete: () => setState(() {
                _localCover = null;
                _existingCoverUrl = null;
              }),
              hasImage: _localCover != null || _existingCoverUrl != null,
            ),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 2),
                image: _localCover != null
                    ? DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(_localCover!.path)
                            : FileImage(File(_localCover!.path))
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : (_existingCoverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_existingCoverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child: (_localCover == null && _existingCoverUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '대표 사진 변경',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              GestureDetector(
                onTap: _showColorPicker,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: _selectedColorIndex != null
                      ? AppConstants.themeColors[_selectedColorIndex!]
                      : Colors.grey[200],
                  backgroundImage: _localLogo != null
                      ? (kIsWeb
                            ? NetworkImage(_localLogo!.path)
                            : FileImage(File(_localLogo!.path))
                                  as ImageProvider)
                      : (_existingLogoUrl != null
                            ? NetworkImage(_existingLogoUrl!)
                            : null),
                  child: (_localLogo == null && _existingLogoUrl == null)
                      ? (_selectedEmoji != null
                            ? Text(
                                _selectedEmoji!,
                                style: const TextStyle(fontSize: 24),
                              )
                            : Icon(
                                Icons.color_lens_rounded,
                                color: Colors.grey[400],
                              ))
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '모임 이름',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF8A80),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A80),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '수정 완료',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🌟 [개조] 모임 멤버 프로필 수정 시트 (카톡 액션 메뉴 적용)
class _GroupProfileEditSheet extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final GroupRepository repository;
  final VoidCallback onUpdated;
  const _GroupProfileEditSheet({
    required this.memberData,
    required this.repository,
    required this.onUpdated,
  });
  @override
  State<_GroupProfileEditSheet> createState() => _GroupProfileEditSheetState();
}

class _GroupProfileEditSheetState extends State<_GroupProfileEditSheet> {
  final TextEditingController _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _localImage;
  String? _existingImageUrl;
  bool _isSaving = false;
  bool _isBirthdayPublic = true;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.memberData['display_name'] ?? '';
    _existingImageUrl = widget.memberData['profile_image_url'];
    _isBirthdayPublic = widget.memberData['is_birthday_public'] ?? true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _showImageActionMenu({
    required VoidCallback onPick,
    required VoidCallback onDelete,
    required bool hasImage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.black87,
                ),
                title: const Text(
                  '앨범에서 사진 선택',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPick();
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    '사진 삭제하기',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _localImage = picked);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.updateGroupMemberProfile(
        memberId: widget.memberData['id'],
        displayName: nickname,
        existingImageUrl: _existingImageUrl,
        newImageFile: _localImage,
        isBirthdayPublic: _isBirthdayPublic,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('🎉 프로필이 수정되었습니다!')));
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 40,
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
            '내 모임 프로필 수정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => _showImageActionMenu(
              onPick: _pickImage,
              onDelete: () => setState(() {
                _localImage = null;
                _existingImageUrl = null;
              }),
              hasImage: _localImage != null || _existingImageUrl != null,
            ),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _localImage != null
                  ? ClipOval(
                      child: kIsWeb
                          ? Image.network(_localImage!.path, fit: BoxFit.cover)
                          : Image.file(
                              File(_localImage!.path),
                              fit: BoxFit.cover,
                            ),
                    )
                  : (_existingImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Colors.grey[400],
                          )),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '닉네임',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFFF8A80),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _isBirthdayPublic,
                  onChanged: (val) =>
                      setState(() => _isBirthdayPublic = val ?? true),
                  activeColor: const Color(0xFFFF8A80),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '이 모임에 내 생일 공개하기 🎂',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A80),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '수정 완료',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... 서랍장 _MemberDrawer 클래스는 이전과 완전히 동일합니다! 그대로 두시면 됩니다! ...
class _MemberDrawer extends StatefulWidget {
  final String groupId, groupName;
  final List<Map<String, dynamic>> members;
  final VoidCallback onMembersUpdated;
  final Color activeColor;
  final bool isDefaultColor;
  final GroupRepository repository;
  final Future<bool?> Function(String, String, String, Color, IconData)
  showDialogFunc;
  final void Function(Map<String, dynamic>) onMemberTap;
  const _MemberDrawer({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.onMembersUpdated,
    required this.activeColor,
    required this.isDefaultColor,
    required this.repository,
    required this.showDialogFunc,
    required this.onMemberTap,
  });
  @override
  State<_MemberDrawer> createState() => _MemberDrawerState();
}

class _MemberDrawerState extends State<_MemberDrawer> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  String _sortType = 'joined';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔗 초대 링크가 복사되었습니다! 카톡에 붙여넣기 해보세요!')),
      );
    }
  }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.addMember(
        widget.groupId,
        _nameController.text.trim(),
      );
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
    final confirm = await widget.showDialogFunc(
      '멤버 내보내기',
      '${member['display_name']} 님을 정말 내보내시겠습니까?',
      '내보내기',
      Colors.redAccent,
      Icons.person_remove_rounded,
    );
    if (confirm == true) {
      try {
        await widget.repository.removeMember(member['id']);
        widget.onMembersUpdated();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('에러: $e')));
      }
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    final currentRole = member['role'];
    final newRole = currentRole == 'host' ? 'member' : 'host';
    final actionText = newRole == 'host' ? '방장으로 승급' : '일반 멤버로 강등';
    final confirm = await widget.showDialogFunc(
      '권한 변경',
      '${member['display_name']} 님을 $actionText 시키겠습니까?',
      '변경',
      widget.activeColor == Colors.grey[200] ? Colors.blue : widget.activeColor,
      Icons.manage_accounts_rounded,
    );
    if (confirm == true) {
      try {
        await widget.repository.updateMemberRole(member['id'], newRole);
        widget.onMembersUpdated();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('권한 변경 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final btnTextColor = widget.isDefaultColor
        ? Colors.white
        : ColorUtils.getTextColor(widget.activeColor);
    List<Map<String, dynamic>> sortedMembers = List.from(widget.members);
    if (_sortType == 'joined') {
      sortedMembers.sort((a, b) => a['joined_at'].compareTo(b['joined_at']));
    } else if (_sortType == 'name') {
      sortedMembers.sort(
        (a, b) => a['display_name'].compareTo(b['display_name']),
      );
    } else if (_sortType == 'rate') {
      sortedMembers.sort((a, b) {
        int r = (b['attendance_rate'] ?? 0.0).compareTo(
          a['attendance_rate'] ?? 0.0,
        );
        return r != 0 ? r : a['joined_at'].compareTo(b['joined_at']);
      });
    }
    String sortLabel = _sortType == 'joined'
        ? '참가순'
        : (_sortType == 'name' ? '가나다순' : '참여율순');
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
                  foregroundColor: btnTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.share_rounded, color: btnTextColor),
                label: Text(
                  '초대링크 복사하기',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: btnTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '멤버 ${sortedMembers.length}명',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(() => _sortType = value),
                    offset: const Offset(0, 30),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            sortLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.grey[800],
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'joined',
                        child: Text('참가순', style: TextStyle(fontSize: 14)),
                      ),
                      const PopupMenuItem(
                        value: 'name',
                        child: Text('가나다순', style: TextStyle(fontSize: 14)),
                      ),
                      const PopupMenuItem(
                        value: 'rate',
                        child: Text('참여율순', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: sortedMembers.isEmpty
                  ? const Center(child: Text('멤버가 없어요.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: sortedMembers.length,
                      itemBuilder: (context, index) {
                        final member = sortedMembers[index];
                        final isHost = member['role'] == 'host';
                        final isMe =
                            currentUserId != null &&
                            member['user_id'] == currentUserId;
                        final String? profileImageUrl =
                            member['profile_image_url'];
                        return ListTile(
                          onTap: () => widget.onMemberTap(member),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    isHost ? '👑' : member['display_name'][0],
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: isHost ? 14 : 16,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            member['display_name'] + (isMe ? ' (나)' : ''),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: isMe
                              ? const SizedBox.shrink()
                              : PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'role') _changeRole(member);
                                    if (value == 'kick') _removeMember(member);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'role',
                                      child: Text(
                                        isHost ? '일반 멤버로 강등' : '방장 권한 부여',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'kick',
                                      child: Text(
                                        '내보내기',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
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

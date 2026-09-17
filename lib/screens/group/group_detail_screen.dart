import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../../utils/color_utils.dart';
import '../../repositories/group_repository.dart';
import 'meetup_create_screen.dart';
import 'meetup_detail_screen.dart';
import 'group_info_screen.dart';
import 'photo_viewer_screen.dart';

import '../../widgets/member_drawer.dart';
import '../../widgets/group_edit_sheets.dart';

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

  void _openMyProfileEditSheet(Map<String, dynamic> memberData) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupProfileEditSheet(
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
        endDrawer: MemberDrawer(
          groupId: widget.groupId,
          groupName: _currentGroupName,
          members: _rankedMembers,
          activeColor: activeColor,
          isDefaultColor: isDefaultColor,
          onMembersUpdated: _loadAllData,
          repository: _repository,
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
                      Tab(text: '사진첩'),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: _meetups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0)
                        return InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MeetupCreateScreen(groupId: widget.groupId),
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
                                  color: isDefaultColor
                                      ? Colors.grey[600]
                                      : activeColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '새로운 만남 기록하기',
                                  style: TextStyle(
                                    color: isDefaultColor
                                        ? Colors.grey[800]
                                        : activeColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      final item = _meetups[index - 1];
                      final title = item['title']?.toString().isNotEmpty == true
                          ? item['title']
                          : '제목 없는 만남';
                      final subText = [
                        item['location'] ?? '',
                        item['menu'] ?? '',
                      ].where((s) => s.toString().isNotEmpty).join(' · ');
                      final attendeeCount =
                          (item['attendances'] as List?)?.length ?? 0;
                      final photos = item['photos'] as List<dynamic>? ?? [];
                      final hasPhoto = photos.isNotEmpty;
                      final bgImageUrl = hasPhoto
                          ? photos.first.toString()
                          : null;
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
                                      color: isDefaultColor
                                          ? Colors.grey[400]
                                          : activeColor,
                                    ),
                                  ),
                                if (!hasPhoto) const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatDate(item['meet_date']),
                                        style: TextStyle(
                                          color: hasPhoto
                                              ? Colors.white70
                                              : Colors.grey[400],
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
                                          color: hasPhoto
                                              ? Colors.white
                                              : Colors.grey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
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
                                                      : activeColor.withOpacity(
                                                          0.1,
                                                        )),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                  ),
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
    final imageUrls = albumPhotos.map((e) => e['url'] as String).toList();

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
}

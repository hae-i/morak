import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../utils/color_utils.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../models/group_model.dart';
import '../../models/meetup_model.dart';
import '../../models/member_model.dart';
import '../../utils/invite_helper.dart';
import 'meetup_create_screen.dart';
import 'meetup_detail_screen.dart';
import 'group_info_screen.dart';
import 'photo_viewer_screen.dart';
import '../../widgets/group/member_drawer.dart';
import '../../widgets/group/group_edit_sheets.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  bool _isLoading = true;
  GroupModel? _group;
  List<MeetupModel> _meetups = [];
  List<MemberModel> _rankedMembers = [];
  List<String> _allAlbumPhotos = [];

  final _groupRepo = locator<GroupRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🌟 isSilentRefresh 가 true면 로딩 화면을 안 띄움!
  Future<void> _loadAllData({bool isSilentRefresh = false}) async {
    if (!isSilentRefresh) {
      setState(() => _isLoading = true); // 처음 들어올 때만 로딩 켜기
    }

    try {
      final data = await _groupRepo.fetchGroupDetailWithRanking(widget.groupId);
      if (mounted) {
        setState(() {
          _group = data['group'];
          _meetups = data['meetups'];
          _rankedMembers = data['rankedMembers'];
          _allAlbumPhotos.clear();
          for (var meetup in _meetups) {
            _allAlbumPhotos.addAll(meetup.photos);
          }
          _isLoading = false; // 끝나면 끄기
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMyProfileEditSheet(MemberModel memberData) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupProfileEditSheet(
        memberData: memberData,
        repository: _groupRepo,
        onUpdated: _loadAllData,
      ),
    );
  }

  void _showMemberProfileSheet(MemberModel member) {
    final bool isHost = member.role == 'host';
    final bool isMe =
        member.userId == (Supabase.instance.client.auth.currentUser?.id ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (isMe)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.settings_rounded, color: Colors.grey[500]),
                    onPressed: () => _openMyProfileEditSheet(member),
                    tooltip: '프로필 수정',
                  ),
                )
              else
                const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: member.profileImageUrl != null
                        ? NetworkImage(member.profileImageUrl!)
                        : null,
                    child: member.profileImageUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
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
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                member.displayName + (isMe ? ' (나)' : ''),
                                style: const TextStyle(
                                  fontSize: 20,
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
                          (member.isBirthdayPublic && member.birthday != null)
                              ? '🎂 생일: ${member.birthday!.replaceAll('-', '. ')}'
                              : (isHost ? '모임 방장' : '일반 멤버'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 🌟 미니멀하고 플랫한 통계 박스
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          '참여한 만남',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${member.attendedCount}회',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 24, color: Colors.grey[200]),
                    Column(
                      children: [
                        const Text(
                          '참석률',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${member.attendanceRate.toInt()}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
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
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _group == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.black87,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final activeColor = ColorUtils.stringToColor(_group!.themeColor);
    final isDefaultColor = activeColor == Colors.grey[200]!;
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    final memberDrawerWidget = MemberDrawer(
      groupId: _group!.id,
      groupName: _group!.name,
      members: _rankedMembers,
      activeColor: activeColor,
      isDefaultColor: isDefaultColor,
      onMembersUpdated: _loadAllData,
      repository: _groupRepo,
      onMemberTap: _showMemberProfileSheet,
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white, // 🌟 배경을 깔끔한 순백색으로 통일하여 답답함 해소!
        endDrawer: isWideScreen ? null : memberDrawerWidget,

        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            _group!.name,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.share_outlined,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () {
                InviteHelper.copyInviteLink(
                  context: context,
                  groupId: _group!.id,
                );
              },
            ),
          ],
        ),

        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildHeaderInfo(activeColor, isDefaultColor),
                  const SizedBox(height: 8),

                  // 🌟 탭바를 아주 심플하게 다이어트
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.black87,
                    indicatorWeight: 2,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.grey[400],
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

            if (isWideScreen) ...[
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFFEEEEEE),
              ),
              SizedBox(width: 300, child: memberDrawerWidget),
            ],
          ],
        ),
      ),
    );
  }

  // 🌟 상단 대형 배너: 뚱뚱한 박스 느낌을 없애고 세련된 카드형으로 개선
  Widget _buildHeaderInfo(Color activeColor, bool isDefaultColor) {
    final bool hasCover = _group!.coverImageUrl != null;
    final bool hasLogo = _group!.logoImageUrl != null;
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: hasCover
              ? Colors.black
              : (isDefaultColor
                    ? Colors.grey[150]
                    : activeColor.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(20),
          image: hasCover
              ? DecorationImage(
                  image: NetworkImage(_group!.coverImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: hasCover
                ? const LinearGradient(
                    colors: [Colors.black45, Colors.black45],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupInfoScreen(groupData: _group!),
                    ),
                  );
                  if (result == 'deleted') {
                    if (mounted) Navigator.pop(context, true);
                  } else if (result == 'updated') {
                    _loadAllData();
                  }
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    image: hasLogo
                        ? DecorationImage(
                            image: NetworkImage(_group!.logoImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: hasLogo
                      ? null
                      : Center(
                          child:
                              (_group!.themeEmoji != null &&
                                  _group!.themeEmoji!.isNotEmpty)
                              ? Text(
                                  _group!.themeEmoji!,
                                  style: const TextStyle(fontSize: 26),
                                )
                              : Icon(
                                  Icons.groups_rounded,
                                  color: activeColor,
                                  size: 26,
                                ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: hasCover ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '만남 기록',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasCover
                                  ? Colors.white70
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: hasCover ? Colors.white24 : Colors.grey[300],
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isWideScreen)
                          _scaffoldKey.currentState?.openEndDrawer();
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_rankedMembers.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: hasCover ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '모임 멤버',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasCover
                                  ? Colors.white70
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
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
      color: Colors.black87,
      onRefresh: () => _loadAllData(isSilentRefresh: true),
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
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '아직 남겨진 기록이 없어요.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MeetupCreateScreen(groupId: _group!.id),
                              ),
                            );
                            if (result == true) _loadAllData();
                          },
                          child: const Text(
                            '첫 만남 기록하기 +',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: _meetups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MeetupCreateScreen(groupId: _group!.id),
                                ),
                              );
                              if (result == true) _loadAllData();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '+ 새로운 만남 기록하기',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      final meetup = _meetups[index - 1];
                      final title = meetup.title ?? '제목 없는 만남';
                      final subText = [
                        meetup.location ?? '',
                        meetup.menu ?? '',
                      ].where((s) => s.isNotEmpty).join(' · ');
                      final attendeeCount = meetup.attendanceMemberIds.length;
                      final hasPhoto = meetup.photos.isNotEmpty;
                      final bgImageUrl = hasPhoto ? meetup.photos.first : null;

                      // 🌟 카드를 슬림하고 감성적으로 변경
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MeetupDetailScreen(
                                meetup: meetup,
                                groupMembers: _rankedMembers,
                                activeColor: activeColor,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 105, // 높이 줄임 (뚱뚱함 해소)
                          decoration: BoxDecoration(
                            color: hasPhoto ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF0F0F0),
                            ), // 은은한 테두리
                            image: hasPhoto
                                ? DecorationImage(
                                    image: NetworkImage(bgImageUrl!),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.3),
                                      BlendMode.darken,
                                    ),
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatDate(meetup.date),
                                      style: TextStyle(
                                        color: hasPhoto
                                            ? Colors.white70
                                            : Colors.grey[400],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: hasPhoto
                                            ? Colors.white
                                            : Colors.black87,
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
                                            fontSize: 12,
                                            color: hasPhoto
                                                ? Colors.white70
                                                : Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (attendeeCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasPhoto
                                        ? Colors.white24
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '👥 $attendeeCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasPhoto
                                          ? Colors.white
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
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
    List<Map<String, dynamic>> albumData = [];
    for (var meetup in _meetups) {
      for (var photo in meetup.photos) {
        albumData.add({'url': photo, 'meetup': meetup});
      }
    }
    final imageUrls = albumData.map((e) => e['url'] as String).toList();

    return RefreshIndicator(
      color: Colors.black87,
      onRefresh: _loadAllData,
      child: albumData.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 등록된 사진이 없어요.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              itemCount: albumData.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoViewerScreen(
                        imageUrls: imageUrls,
                        initialIndex: index,
                        meetup: albumData[index]['meetup'],
                        groupMembers: _rankedMembers,
                        activeColor: activeColor,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      10,
                    ), // 모서리 라운드 살짝 줄여서 세련되게
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 120,
                        color: Colors.grey[100],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

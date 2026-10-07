// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/color_utils.dart';
import '../../utils/ui_utils.dart';
import '../../utils/data_refresh.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../models/group_model.dart';
import '../../models/group_detail_data.dart';
import '../../providers/group_detail_controller.dart';
import '../../widgets/group/member_profile_sheet.dart';
import '../../models/meetup_model.dart';
import '../../models/member_model.dart';
import '../../utils/invite_helper.dart';
import 'meetup_create_screen.dart';
import 'meetup_detail_screen.dart';
import 'group_info_screen.dart';
import 'photo_viewer_screen.dart';
import '../../constants/app_constants.dart';
import '../../widgets/group/member_drawer.dart';
import '../../widgets/group/group_attendance_summary.dart';
import '../../widgets/group/group_edit_sheets.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/request_error_view.dart';

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

  bool _showWideSidebar = true;
  bool _isLeaving = false;
  final _groupRepo = locator<GroupRepository>();
  late final GroupDetailController _detail;
  // === 수정한 내용: 기존 UI는 읽기 전용 상세 상태를 사용하고 비동기 처리는 Controller에 위임한다 ===
  bool get _isLoading => _detail.isLoading;
  GroupModel? get _group => _detail.group;
  List<MeetupModel> get _meetups => _detail.meetups;
  List<MemberModel> get _rankedMembers => _detail.rankedMembers;
  List<AlbumPhoto> get _albumData => _detail.albumPhotos;
  int get _totalMeetups => _detail.totalMeetups;
  bool get _hasMoreMeetups => _detail.hasMore;
  bool get _loadingMoreMeetups => _detail.isLoadingMore;
  bool get _pageFailed => _detail.pageFailed;
  @override
  void initState() {
    super.initState();
    _detail = GroupDetailController(
      repository: _groupRepo,
      groupId: widget.groupId,
    );
    _detail.addListener(_onDetailChanged);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAllData();
  }

  @override
  void dispose() {
    _detail.removeListener(_onDetailChanged);
    _detail.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onDetailChanged() {
    if (mounted) setState(() {});
  }

  // === 수정한 내용: 화면 메시지와 조회 상태의 책임을 나누고 폐기된 요청에는 메시지를 표시하지 않는다 ===
  Future<void> _loadAllData({bool isSilentRefresh = false}) async {
    final result = await _detail.load(silent: isSilentRefresh);
    if (mounted && result == GroupDetailLoadResult.failed && _group != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임을 새로 불러오지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _loadMoreMeetups() => _detail.loadMore();
  // === 수정한 내용: 로고와 사이드바의 설정 진입을 같은 경로로 처리하고 복귀 결과를 갱신한다 ===
  Future<void> _openGroupSettings() async {
    final group = _group;
    if (!mounted || group == null) return;
    _scaffoldKey.currentState?.closeEndDrawer();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoScreen(groupData: group)),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context, true);
    } else if (result == 'updated') {
      await _loadAllData();
    }
  }

  // === 수정한 내용: 나가기는 확인 후 본인 멤버를 비활성화하고 방장은 먼저 위임하도록 안내한다 ===
  Future<void> _leaveGroup() async {
    if (_isLeaving) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final mine = _rankedMembers
        .where((m) => m.userId == userId && userId != null)
        .firstOrNull;
    if (mine == null) return;
    // === 수정한 내용: 확인 전에 서랍을 닫아 탈퇴 성공 시 서랍만 닫히는 대신 모임 화면을 종료한다 ===
    _scaffoldKey.currentState?.closeEndDrawer();
    _isLeaving = true;
    try {
      if (mine.role == 'host') {
        UiUtils.showWarningDialog(
          context: context,
          title: '방장 위임이 필요합니다',
          message: '다른 멤버를 방장으로 지정한 뒤 모임을 나가 주세요.',
        );
        return;
      }
      final confirmed = await UiUtils.showBeautifulDialog(
        context: context,
        title: '모임 나가기',
        content: '이 모임을 나가시겠습니까? 나가면 모임 사진과 기록을 볼 수 없습니다.',
        confirmText: '나가기',
        confirmColor: AppConstants.dangerColor,
        icon: Icons.logout_rounded,
      );
      if (!mounted ||
          confirmed != true ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      await _groupRepo.leaveGroup(widget.groupId);
      PrivatePhotos.invalidate(clearMemoryCache: true);
      if (mounted && Supabase.instance.client.auth.currentUser?.id == userId) {
        refreshHomeFeed(context);
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모임을 나가지 못했습니다. 방장 위임 여부와 연결 상태를 확인해 주세요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _shareGroup() async {
    final group = _group;
    if (!mounted || group == null) return;
    try {
      await InviteHelper.copyInviteLink(context: context, groupId: group.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대 링크를 공유하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  Widget _buildPageFooter() => Padding(
    padding: const EdgeInsets.all(12),
    child: _loadingMoreMeetups
        ? const Center(child: CircularProgressIndicator())
        : Button(
            text: _pageFailed ? '기록 조회 다시 시도' : '기록 더 불러오기',
            onPressed: _loadMoreMeetups,
          ),
  );

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

  // === 수정한 내용: 화면은 시트 열기와 편집 이동만 담당하고 표시 내용은 Widget으로 분리한다 ===
  void _showMemberProfileSheet(MemberModel member) {
    final isMe =
        member.userId == (Supabase.instance.client.auth.currentUser?.id ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => MemberProfileSheet(
        member: member,
        isMe: isMe,
        onEdit: () => _openMyProfileEditSheet(member),
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppConstants.scaffoldBackground,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppConstants.primaryColor,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('모임')),
        body: RequestErrorView(
          message: '모임을 불러오지 못했습니다.',
          onRetry: _loadAllData,
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
      onSettings: _openGroupSettings,
      onShare: _shareGroup,
      onLeave: _isLeaving ? null : _leaveGroup,
      onClose: isWideScreen
          ? () => setState(() => _showWideSidebar = false)
          : null,
    );
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeEndDrawer();
          } else {
            Navigator.pop(context, true);
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppConstants.scaffoldBackground,
        endDrawer: isWideScreen ? null : memberDrawerWidget,
        // === 수정한 내용: 넓은 화면 상단바를 복원하고 메뉴 버튼은 화면 폭에 맞게 사이드바를 연다 ===
        appBar: AppBar(
          backgroundColor: AppConstants.scaffoldBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppConstants.textTitle,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            _group!.name,
            style: const TextStyle(
              color: AppConstants.textTitle,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          actions: [
            IconButton(
              tooltip: '모임 메뉴',
              icon: const Icon(
                Icons.menu_rounded,
                color: AppConstants.textTitle,
              ),
              onPressed: () {
                if (isWideScreen) {
                  setState(() => _showWideSidebar = !_showWideSidebar);
                } else {
                  _scaffoldKey.currentState?.openEndDrawer();
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildHeaderInfo(activeColor, isDefaultColor),
                    const SizedBox(height: 8),

                    TabBar(
                      controller: _tabController,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      indicatorColor: AppConstants.textTitle,
                      indicatorWeight: 2,
                      labelColor: AppConstants.textTitle,
                      unselectedLabelColor: AppConstants.textCaption,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: '만남 기록'),
                        Tab(text: '사진첩'),
                        Tab(text: '함께한 시간'),
                      ],
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (_tabController.index != 2 &&
                              notification.metrics.axis == Axis.vertical &&
                              notification.metrics.extentAfter < 300 &&
                              !_pageFailed) {
                            _loadMoreMeetups();
                          }
                          return false;
                        },
                        child: TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildMeetupTab(activeColor, isDefaultColor),
                            _buildAlbumTab(activeColor, isDefaultColor),
                            GroupAttendanceSummary(
                              members: _rankedMembers,
                              totalMeetups: _totalMeetups,
                              onRefresh: () =>
                                  _loadAllData(isSilentRefresh: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 🌟 3. 넓은 화면 전용: 띡띡 끊기지 않고 스르륵 부드럽게 나타나는 사이드바 애니메이션 적용!
              if (isWideScreen)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350), // 0.35초 동안 스르륵
                  curve: Curves.easeInOut,
                  width: _showWideSidebar ? 301 : 0, // 상태에 따라 너비가 줄었다 늘어남
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics:
                        const NeverScrollableScrollPhysics(), // 내용물 찌그러짐 방지
                    child: Row(
                      children: [
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0xFFEEEEEE),
                        ),
                        SizedBox(width: 300, child: memberDrawerWidget),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 상단 대형 배너 (로고 및 모임 멤버 터치 이벤트 분리 완료!)
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
                  image: privatePhoto(_group!.coverImageUrl!),
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
              // 🌟 4. 프로필 로고 이미지 (무조건 그룹 정보 수정 화면으로 이동!)
              GestureDetector(
                onTap: _openGroupSettings,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    image: hasLogo
                        ? DecorationImage(
                            image: privatePhoto(_group!.logoImageUrl!),
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
                            '$_totalMeetups',
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

                    // 🌟 5. 오직 이 '모임 멤버' 텍스트를 눌렀을 때만 사이드바가 제어됩니다!
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isWideScreen) {
                          _scaffoldKey.currentState
                              ?.openEndDrawer(); // 📱 작은 화면에선 우측 서랍 열기
                        } else {
                          setState(
                            () => _showWideSidebar = !_showWideSidebar,
                          ); // 💻 넓은 화면에선 스무스하게 닫기/열기
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // === 수정한 내용: 과거 출석용 탈퇴 멤버는 현재 멤버 수에서 제외한다 ===
                          Text(
                            '${_rankedMembers.where((m) => m.isActive).length}',
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
                        const SizedBox(height: 24), // 🌟 3. 어색하게 붙어있던 간격 해결!
                        SizedBox(
                          width: 220, // 🌟 4. 버튼이 화면 꽉 차지 않게 날렵한 너비 지정
                          child: Button(
                            text: '+ 새로운 만남 기록하기',
                            type: ButtonType.outlined,
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
                    itemCount: _meetups.length + 1 + (_hasMoreMeetups ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _meetups.length + 1) {
                        return _buildPageFooter();
                      }
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Button(
                            text: '+ 새로운 만남 기록하기',
                            type: ButtonType.outlined,
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

                      return GestureDetector(
                        onTap: () async {
                          // === 수정한 내용: 상세 화면에서 돌아온 뒤 기록과 출석 통계를 다시 읽는다 ===
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MeetupDetailScreen(
                                meetup: meetup,
                                groupMembers: _rankedMembers,
                                activeColor: activeColor,
                              ),
                            ),
                          );
                          if (mounted) _loadAllData(isSilentRefresh: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 105,
                          decoration: BoxDecoration(
                            color: hasPhoto
                                ? Colors.black
                                : AppConstants.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppConstants.borderColor),
                            image: hasPhoto
                                ? DecorationImage(
                                    image: privatePhoto(bgImageUrl!),
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
                                      // === 수정한 내용: 만남 목록에서도 기록 작성자를 표시한다 ===
                                      '${_formatDate(meetup.date)} · ${meetup.authorLabel}',
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
    final albumData = _albumData;
    final imageUrls = albumData.map((e) => e.url).toList();

    return RefreshIndicator(
      color: Colors.black87,
      onRefresh: () => _loadAllData(isSilentRefresh: true),
      child: Column(
        children: [
          Expanded(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: albumData.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        // === 수정한 내용: 앨범에서 연 기록을 편집하거나 삭제한 뒤에도 상위 앨범과 통계를 갱신한다 ===
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoViewerScreen(
                                imageUrls: imageUrls,
                                initialIndex: index,
                                meetup: albumData[index].meetup,
                                photoMeetups: albumData
                                    .map((entry) => entry.meetup)
                                    .toList(),
                                groupMembers: _rankedMembers,
                                activeColor: activeColor,
                              ),
                            ),
                          );
                          if (mounted) _loadAllData(isSilentRefresh: true);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            10,
                          ), // 모서리 라운드 살짝 줄여서 세련되게
                          child: PrivatePhotoImage(
                            imageUrl: imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 120,
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
          ),
          if (_hasMoreMeetups) _buildPageFooter(),
        ],
      ),
    );
  }
}

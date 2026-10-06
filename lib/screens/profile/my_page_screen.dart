// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_user_provider.dart';

import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../utils/ui_utils.dart';
import '../../models/user_model.dart';
import '../../locator.dart';
import '../../repositories/user_repository.dart';
import 'profile_edit_screen.dart';
import 'account_info_screen.dart';
import '../../services/external_links.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  final ExternalLinks? externalLinks;
  const MyPageScreen({super.key, this.externalLinks});
  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  UserModel? _myProfile;
  bool _loadFailed = false;
  bool _isSigningOut = false;
  int _loadGeneration = 0;
  String? _userId = Supabase.instance.client.auth.currentUser?.id;
  final _userRepo = locator<UserRepository>();

  // === 수정한 내용: 메일 앱/브라우저 실패를 처리하고 이메일 주소를 직접 복사할 수 있게 안내한다 ===
  Future<void> _openSupportEmail() async {
    try {
      await (widget.externalLinks ?? ExternalLinks()).openSupportEmail();
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('고객센터 / 피드백'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('메일 앱을 열 수 없습니다. 아래 주소로 문의해 주세요.'),
              SizedBox(height: 12),
              SelectableText(ExternalLinks.supportEmail),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      await (widget.externalLinks ?? ExternalLinks()).openPrivacyPolicy();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('개인정보처리방침 페이지를 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // === 수정한 내용: 프로필 조회 실패와 계정 변경을 처리하여 이전 사용자 정보와 비동기 예외를 방지한다 ===
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (mounted &&
          generation == _loadGeneration &&
          Supabase.instance.client.auth.currentUser?.id == userId) {
        setState(() {
          _myProfile = profile;
          _loadFailed = profile == null;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadFailed = true);
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    if (_isSigningOut) return;
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '로그아웃',
      content: '정말 로그아웃 하시겠습니까?\n언제든 다시 돌아오실 수 있어요.',
      confirmText: '로그아웃',
      confirmColor: Colors.redAccent,
      icon: Icons.logout_rounded,
    );

    if (mounted && confirm == true) {
      // === 수정한 내용: 로그아웃 실패는 사용자에게 알리고 중복 요청과 잘못된 화면 이동을 막는다 ===
      _isSigningOut = true;
      try {
        await _userRepo.signOut();
        if (mounted) context.go('/login');
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그아웃하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      } finally {
        _isSigningOut = false;
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '정말 탈퇴하시겠어요?',
      // === 수정한 내용: 탈퇴 전 방장 위임이 필요하며 다른 멤버의 기록까지 삭제된다고 안내하지 않는다 ===
      content: '계정과 개인정보가 삭제됩니다. 모임의 참석 기록과 작성 글은 탈퇴한 멤버로 남습니다.\n방장인 모임은 먼저 다른 멤버에게 위임해 주세요.',
      confirmText: '탈퇴하기',
      confirmColor: Colors.redAccent,
      icon: Icons.sentiment_dissatisfied_rounded,
    );

    if (confirm == true) {
      try {
        await _userRepo.deleteAccount();
        if (mounted) context.go('/login');
      } catch (e) {
        if (mounted) {
          UiUtils.showWarningDialog(
            context: context,
            title: '탈퇴 실패',
            message: '회원탈퇴를 완료하지 못했습니다. 방장인 모임을 먼저 위임하고 연결 상태를 확인해 주세요.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) {
      if (!next.hasValue || next.value == _userId) return;
      _userId = next.value;
      setState(() => _myProfile = null);
      _loadUserProfile();
    });
    final nickname =
        _myProfile?.displayName ?? (_loadFailed ? '프로필을 다시 불러와 주세요' : '로딩중...');
    final profileUrl = _myProfile?.profileImageUrl;

    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppConstants.textTitle,
          ),
        ),
        backgroundColor: AppConstants.scaffoldBackground,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.transparent,
                  backgroundImage: profileUrl != null
                      ? privatePhoto(profileUrl)
                      : const AssetImage('assets/images/profile.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$nickname 님, 반가워요 !',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (_myProfile == null) {
                      await _loadUserProfile();
                      return;
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileEditScreen(),
                      ),
                    );
                    if (result == true) _loadUserProfile();
                  },
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // 🌟 3. 앱 설정 메뉴 그룹
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: const Text(
              '앱 설정',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppConstants.textCaption,
              ),
            ),
          ),
          _buildMenuTile(
            Icons.notifications_none_rounded,
            '알림 설정',
            onTap: () {},
          ),
          _buildMenuTile(
            Icons.help_outline_rounded,
            '고객센터 / 피드백',
            onTap: _openSupportEmail,
          ),

          const SizedBox(height: 28),

          // 🌟 3. 계정 설정 메뉴 그룹
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '계정 설정',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
          ),
          _buildMenuTile(
            Icons.person_outline_rounded,
            '계정 정보',
            // === 수정한 내용: 비어 있던 계정 정보 메뉴를 인증 계정 상세 화면에 연결한다 ===
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
            ),
          ),
          _buildMenuTile(
            Icons.lock_outline_rounded,
            '개인정보 보호',
            onTap: _openPrivacyPolicy,
          ),
          _buildMenuTile(
            Icons.logout_rounded,
            '로그아웃',
            isDestructive: true,
            onTap: _showLogoutDialog,
          ),

          const SizedBox(height: 16),

          Center(
            child: InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    color: AppConstants.textCaption,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppConstants.textCaption,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderColor),
      ),
      // === 수정한 내용: 메뉴 타일에 투명 Material을 제공해 기존 모양을 유지하면서 잉크 렌더링 assertion을 방지한다 ===
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            icon,
            color: isDestructive
                ? AppConstants.dangerColor
                : AppConstants.textBody,
            size: 22,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDestructive
                  ? AppConstants.dangerColor
                  : AppConstants.textTitle,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppConstants.textCaption,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

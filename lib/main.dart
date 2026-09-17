import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants/app_constants.dart';
import 'repositories/user_repository.dart';
import 'repositories/group_repository.dart';
import 'widgets/common/common_widgets.dart';

import 'screens/main_skeleton.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MorakApp());
}

class MorakApp extends StatelessWidget {
  const MorakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
        ), // 🌟 하드코딩 제거
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget _currentWidget = const Scaffold(
    body: Center(
      child: CircularProgressIndicator(color: AppConstants.primaryColor),
    ), // 🌟 하드코딩 제거
  );

  late AppLinks _appLinks;
  final _userRepo = UserRepository(); // 🌟 레포지토리 주입

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn) {
        if (session == null) {
          if (mounted) setState(() => _currentWidget = const LoginScreen());
        } else {
          await _routeUser(session.user.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _currentWidget = const LoginScreen());
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'morak' && uri.host == 'invite') {
        final groupId = uri.queryParameters['groupId'];
        final groupName = uri.queryParameters['groupName'] ?? '모임';
        if (groupId != null) {
          _showJoinProfileSheet(groupId, groupName);
        }
      }
    });
  }

  void _showJoinProfileSheet(String groupId, String groupName) {
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 다시 초대 링크를 눌러주세요!')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _GroupJoinSheet(groupId: groupId, groupName: groupName),
    );
  }

  Future<void> _routeUser(String userId) async {
    try {
      // 🌟 DB 직접 조회를 레포지토리로 완벽하게 대체!
      final userData = await _userRepo.fetchMyGlobalProfile();

      if (mounted) {
        setState(() {
          if (userData == null) {
            _currentWidget = const ProfileSetupScreen();
          } else {
            _currentWidget = const MainSkeleton();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentWidget = Scaffold(
            body: Center(
              child: Text(
                '에러 발생:\n$e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _currentWidget;
  }
}

// ==========================================
// 🌟 [핵심] 모임 가입 시 프로필 확인/수정 바텀 시트
// ==========================================
class _GroupJoinSheet extends StatefulWidget {
  final String groupId;
  final String groupName;

  const _GroupJoinSheet({required this.groupId, required this.groupName});

  @override
  State<_GroupJoinSheet> createState() => _GroupJoinSheetState();
}

class _GroupJoinSheetState extends State<_GroupJoinSheet> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _globalProfileImageUrl;
  bool _isBirthdayPublic = true;

  final _userRepo = UserRepository(); // 🌟 레포지토리
  final _groupRepo = GroupRepository(); // 🌟 레포지토리

  @override
  void initState() {
    super.initState();
    _loadGlobalProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalProfile() async {
    try {
      // 🌟 DB 찌꺼기를 날리고 레포지토리에서 우아하게 Model을 받아옵니다.
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _nicknameController.text = profile.displayName;
          _globalProfileImageUrl = profile.profileImageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // 🌟 가입 로직도 레포지토리에게 위임!
      await _groupRepo.joinGroup(
        groupId: widget.groupId,
        nickname: nickname,
        profileImageUrl: _globalProfileImageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${widget.groupName} 모임에 가입되었습니다!'),
            backgroundColor: AppConstants.primaryColor, // 🌟 하드코딩 제거
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 가입된 모임이거나 에러가 발생했습니다.')),
        );
      }
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
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor,
                ),
              ),
            ) // 🌟 하드코딩 제거
          : Column(
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
                Text(
                  '💌 ${widget.groupName}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '모임 프로필 설정',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: _globalProfileImageUrl != null
                      ? NetworkImage(_globalProfileImageUrl!)
                      : null,
                  child: _globalProfileImageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: Colors.grey[300],
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이 모임에서 사용할 닉네임',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                // 🌟 길었던 TextField 코드를 우리가 만든 CustomTextField로 1줄 컷!
                CustomTextField(
                  controller: _nicknameController,
                  hint: '예: 모락대장',
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
                        activeColor: AppConstants.primaryColor,
                      ),
                    ), // 🌟 하드코딩 제거
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
                    onPressed: _isSaving ? null : _joinGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ), // 🌟 하드코딩 제거
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '이 프로필로 참여하기',
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

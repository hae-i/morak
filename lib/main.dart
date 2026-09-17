import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'screens/main_skeleton.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kzatuowxrixutuclglfj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6YXR1b3d4cml4dXR1Y2xnbGZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNDYxMDAsImV4cCI6MjEwMDcyMjEwMH0.IaEPcu2f73l2HUhiy9h6e3acelrL5CpR3T9a7OQj7-E',
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A80)),
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
    body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80))),
  );

  late AppLinks _appLinks;

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
          // 🌟 투박한 팝업 대신, 예쁜 프로필 설정 시트를 띄웁니다!
          _showJoinProfileSheet(groupId, groupName);
        }
      }
    });
  }

  // 🌟 새롭게 추가된 바텀 시트 호출 로직!
  void _showJoinProfileSheet(String groupId, String groupName) {
    if (!mounted) return;

    // 로그인이 안 되어 있다면 막기
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
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

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

  bool _isBirthdayPublic = true; // 🌟 생일 공개 여부 변수 추가!

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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('display_name, profile_image_url')
          .eq('id', userId)
          .single();
      setState(() {
        _nicknameController.text = data['display_name'] ?? '';
        _globalProfileImageUrl = data['profile_image_url'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 모임 멤버로 저장하기!
  Future<void> _joinGroup() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // group_members 테이블에 프사 정보까지 싹 담아서 인서트!
      await Supabase.instance.client.from('group_members').insert({
        'group_id': widget.groupId,
        'user_id': user.id,
        'role': 'member',
        'display_name': nickname,
        'profile_image_url': _globalProfileImageUrl, // 모임별 프로필 프사 적용
      });

      if (mounted) {
        Navigator.pop(context); // 시트 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${widget.groupName} 모임에 가입되었습니다!'),
            backgroundColor: const Color(0xFFFF8A80),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 가입된 모임이거나 에러가 발생했습니다.')),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // 키보드 올라오는 높이

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
                child: CircularProgressIndicator(color: Color(0xFFFF8A80)),
              ),
            )
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

                // 글로벌 프로필 사진을 띄워줌
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

                // 닉네임 수정 가능하게 텍스트 필드 제공
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이 모임에서 사용할 닉네임',
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
                    onPressed: _isSaving ? null : _joinGroup,
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

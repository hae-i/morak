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
      home: const AuthGate(), // 💡 앱이 켜지면 무조건 게이트(검문소)로 갑니다.
    );
  }
}

// 🌟 핵심: 로그인 상태를 감지하고 완벽하게 길을 찾아주는 검문소!
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // 처음에 앱을 켜면 일단 로딩 화면을 띄워놓고 검사를 시작합니다.
  Widget _currentWidget = const Scaffold(
    body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80))),
  );

  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    // 수파베이스의 로그인 상태 감지 레이더 작동!
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // 앱을 처음 켰을 때(initialSession) 거나, 방금 로그인을 성공(signedIn) 했을 때!
      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn) {
        if (session == null) {
          // 로그아웃 상태면 👉 로그인 화면으로!
          if (mounted) setState(() => _currentWidget = const LoginScreen());
        } else {
          // 로그인된 상태면 👉 DB를 뒤져서 닉네임이 있는지 확인하러 고고!
          await _routeUser(session.user.id);
        }
      }
      // 로그아웃(signedOut) 버튼을 눌렀을 때!
      else if (event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _currentWidget = const LoginScreen());
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 앱이 켜져있거나 백그라운드에 있을 때 링크를 누르면 여기서 감지합니다!
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'morak' && uri.host == 'invite') {
        final groupId = uri.queryParameters['groupId'];
        final groupName = uri.queryParameters['groupName'] ?? '모임';

        if (groupId != null) {
          _showJoinDialog(groupId, groupName);
        }
      }
    });
  }

  // 🌟 가입 의사를 물어보는 팝업 띄우기!
  void _showJoinDialog(String groupId, String groupName) {
    // 혹시 앱이 백그라운드에 있다가 화면이 아직 안 그려졌을 때를 대비한 방어 로직
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '모임 초대 💌',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: Text(
            '[$groupName] 모임에 참여하시겠습니까?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기 (거절)
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫고
                _joinGroup(groupId, groupName); // 💡 승낙했으니 진짜 가입 로직 실행!
              },
              child: const Text(
                '참여하기',
                style: TextStyle(
                  color: Color(0xFFFF8A80),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🌟 수파베이스에 멤버로 넣어주는 로직
  Future<void> _joinGroup(String groupId, String groupName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // 로그인이 안 되어 있으면 일단 로그인부터 하라고 알림!
      return;
    }

    try {
      // 1. 유저 닉네임 가져오기
      final userData = await Supabase.instance.client
          .from('users')
          .select('display_name')
          .eq('id', user.id)
          .single();
      final nickname = userData['display_name'];

      // 2. 멤버 테이블에 쏙 추가! (role은 일반 'member')
      await Supabase.instance.client.from('group_members').insert({
        'group_id': groupId,
        'user_id': user.id,
        'role': 'member',
        'display_name': nickname,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // 3. 가입 완료 메시지! (이후 자연스럽게 피드 탭으로 넘어가거나 새로고침됨)
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('🎉 $groupName 모임에 가입되었습니다!')));
      }
    } catch (e) {
      // 이미 가입된 경우 등 에러 처리
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 가입된 모임이거나 오류가 발생했습니다.')),
        );
    }
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
            // 가입 이력이 없다면 👉 닉네임 입력 화면으로!
            _currentWidget = const ProfileSetupScreen();
          } else {
            // 가입 이력이 있다면 👉 본인 피드(MainSkeleton)로!
            _currentWidget = const MainSkeleton();
          }
        });
      }
    } catch (e) {
      debugPrint('라우팅 에러: $e');
      // 🚨 핵심 수정: 에러가 났다고 로그인 화면으로 쫓아내지 않고, 화면에 에러를 띄웁니다!
      if (mounted) {
        setState(() {
          _currentWidget = Scaffold(
            body: Center(
              child: Text(
                '유저 정보를 불러오는 중 에러가 발생했습니다.\n\n$e',
                textAlign: TextAlign.center,
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

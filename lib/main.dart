import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Widget _currentWidget = const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A80))));

  @override
  void initState() {
    super.initState();

    // 수파베이스의 로그인 상태 감지 레이더 작동!
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // 앱을 처음 켰을 때(initialSession) 거나, 방금 로그인을 성공(signedIn) 했을 때!
      if (event == AuthChangeEvent.initialSession || event == AuthChangeEvent.signedIn) {
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

  // 지은 님이 기획하신 '가입 이력(닉네임) 검사' 함수!
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
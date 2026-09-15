import 'dart:async'; // 👈 감지기를 위해 추가
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../group/my_group_screen.dart';
import '../profile/profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isGoogleInitialized = false;
  StreamSubscription<AuthState>? _authStateSubscription; // 💡 로그인 상태 감지기!

  @override
  void initState() {
    super.initState();
    // 화면이 켜지자마자 감지기 작동 시작!
    _setupAuthListener();
  }

  // 🌟 핵심: 로그인 상태를 24시간 감시하는 레이더!
  void _setupAuthListener() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      // 누군가 로그인에 성공했거나, 웹 새로고침 후 로그인 상태가 유지되어 있다면?
      if (session != null) {
        // 즉시 DB를 뒤져서 닉네임 설정 여부를 확인하고 화면 이동!
        await _checkUserAndRoute(session.user.id);
      }
    });
  }

  // 길잡이(라우팅) 로직을 아예 따로 함수로 뺐습니다!
  Future<void> _checkUserAndRoute(String userId) async {
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        if (userData == null) {
          // 처음 온 유저 👉 닉네임 설정
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        } else {
          // 기존 유저 👉 내 모임
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyGroupScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('라우팅 에러: $e');
    }
  }

  @override
  void dispose() {
    // 화면이 꺼질 땐 감지기도 꺼주기
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
        );
      } else {
        const webClientId = '403079315316-hq0rgut0fqs2o4igfp3q7hponq31poq7.apps.googleusercontent.com';
        final googleSignIn = GoogleSignIn.instance;

        if (!_isGoogleInitialized) {
          await googleSignIn.initialize(serverClientId: webClientId);
          _isGoogleInitialized = true;
        }

        final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return;
        }

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) throw 'ID 토큰을 찾을 수 없어요.';

        // 💡 여기서 로그인이 완료되면? 위에 만들어둔 '감지기'가 알아서 반응해서 화면을 넘겨줍니다!
        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
      }
    } catch (e) {
      if (!e.toString().toLowerCase().contains('cancel')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: const Color(0xFFFF8A80).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.groups_rounded, color: Color(0xFFFF8A80), size: 40),
              ),
              const SizedBox(height: 24),
              const Text('모락', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFFF8A80))),
              const SizedBox(height: 8),
              Text('우리들의 모임 기록, 깔끔하게', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _googleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey[800],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFFFF8A80))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata_rounded, size: 32, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Google로 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isGoogleInitialized = false;

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
          // 🌟 핵심 1 (웹용): 구글아, 기억력 지우고 무조건 '계정 선택 창' 띄워!
          queryParams: {
            'prompt': 'select_account',
          },
        );
      } else {
        const webClientId = '403079315316-hq0rgut0fqs2o4igfp3q7hponq31poq7.apps.googleusercontent.com';
        final googleSignIn = GoogleSignIn.instance;

        if (!_isGoogleInitialized) {
          await googleSignIn.initialize(serverClientId: webClientId);
          _isGoogleInitialized = true;
        }

        // 🌟 핵심 2 (앱용): 기존에 남아있는 구글 앱 로그인 찌꺼기 완벽하게 날리기!
        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return;
        }

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) throw 'ID 토큰을 찾을 수 없어요.';

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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../locator.dart';
import '../repositories/user_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) context.go('/login');
        return;
      }

      // 🌟 레포지토리에서 안전하게 프로필 확인
      final profile = await locator<UserRepository>().fetchMyGlobalProfile();
      if (mounted) {
        if (profile == null) {
          context.go('/profile-setup');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint('🚨 스플래시 라우팅 에러: $e');
      if (mounted) context.go('/profile-setup'); // 최후의 안전장치
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppConstants.primaryColor),
      ),
    );
  }
}

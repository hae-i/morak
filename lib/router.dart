import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/main_skeleton.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'widgets/group/group_join_sheet.dart';
import 'screens/group/group_detail_screen.dart';

String? _pendingInvite;
// === 수정한 내용: 로그인과 프로필 설정 동안 내부 초대 목적지만 보관하여 가입 흐름을 이어 간다 ===
String destinationAfterProfile({required bool hasProfile}) {
  if (!hasProfile) return '/profile-setup';
  final target = _pendingInvite;
  _pendingInvite = null;
  return target ?? '/home';
}

void clearPendingInvite() => _pendingInvite = null;

// 🌟 앱의 전체 길안내를 담당하는 GoRouter
final router = GoRouter(
  // 앱이 처음 켜지면 무조건 AuthGate로
  initialLocation: '/',

  // 🌟 Auth Guard: 라우팅될 때마다 로그인 상태를 확인
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    if (state.uri.path == '/invite' && session == null) {
      final groupId = state.uri.queryParameters['groupId']?.trim();
      if (groupId != null && groupId.isNotEmpty) {
        _pendingInvite = Uri(
          path: '/invite',
          queryParameters: {'groupId': groupId},
        ).toString();
      }
    }

    // 로그인이 안 되어 있는데 다른 화면으로 가려고 하면? -> 로그인 화면으로 쫓아냄
    if (session == null && !isLoggingIn) return '/login';

    // 로그인이 되어 있는데 로그인 화면으로 가려고 하면? -> 홈으로 보냄
    if (session != null && isLoggingIn) return '/home';

    return null; // 문제없으면 원래 가려던 곳으로 패스!
  },

  routes: [
    // 🚪 대문 (자동 라우팅 대기소)
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    // 🔑 로그인 화면
    // === 수정한 내용: 로그인·로그아웃 전환을 짧은 페이드로 연결하고 기존 인증 목적지는 유지한다 ===
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _authPage(state, const LoginScreen()),
    ),
    // 🏠 홈 화면 (메인 뼈대)
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _authPage(state, const MainSkeleton()),
    ),
    // 👤 초기 프로필 설정 화면
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),

    // 💌 초대 링크 딥링크 처리 (morak://invite?groupId=...&groupName=...)
    GoRoute(
      path: '/invite',
      builder: (context, state) {
        final groupId = state.uri.queryParameters['groupId'] ?? '';
        return _InviteScreen(groupId: groupId);
      },
    ),

    GoRoute(
      path: '/group_detail',
      builder: (context, state) {
        final groupId = state.uri.queryParameters['groupId'] ?? '';

        return GroupDetailScreen(groupId: groupId);
      },
    ),
  ],
);

// === 수정한 내용: 초대 시트는 화면 생성 시 한 번만 열어 rebuild로 인한 중복 가입 창을 방지한다 ===
class _InviteScreen extends StatefulWidget {
  final String groupId;
  const _InviteScreen({required this.groupId});
  @override
  State<_InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<_InviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite());
  }

  Future<void> _openInvite() async {
    if (!mounted) return;
    if (widget.groupId.trim().isEmpty) {
      context.go('/home');
      return;
    }
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupJoinSheet(groupId: widget.groupId),
    );
    if (!mounted) return;
    context.go(
      joined == true
          ? Uri(
              path: '/group_detail',
              queryParameters: {'groupId': widget.groupId},
            ).toString()
          : '/home',
    );
  }

  @override
  Widget build(BuildContext context) => const MainSkeleton();
}

CustomTransitionPage<void> _authPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

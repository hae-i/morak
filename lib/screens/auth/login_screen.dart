// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../constants/app_constants.dart';
import '../../widgets/common/common_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isGoogleInitialized = false;

  // 🌟 스크롤 컨트롤러 및 현재 페이지 상태
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _introData = [
    (
      icon: Icons.auto_stories_rounded,
      title: '만남이 지나도, 추억은 남도록',
      description: '언제, 어디서, 누구와 만났는지.\n사진과 함께 그날의 기억을 모아 보세요.',
      accent: Color(0xFFF3D2BA),
    ),
    (
      icon: Icons.group_add_rounded,
      title: '우리의 기록을 한곳에',
      description: '초대 링크로 소중한 사람들을 초대하고\n같은 모임에서 만남을 기록해 보세요.',
      accent: Color(0xFFDCE7DC),
    ),
    (
      icon: Icons.photo_album_rounded,
      title: '사진마다 돌아갈 추억이 있어요',
      description: '사진첩에서 사진을 둘러보고\n그 사진을 남긴 만남으로 돌아가 보세요.',
      accent: Color(0xFFE6DFF0),
    ),
    (
      icon: Icons.favorite_rounded,
      title: '함께한 시간이 쌓여요',
      description: '함께한 만남과 참석 기록을 돌아보며\n우리 모임만의 이야기를 만들어 가세요.',
      accent: Color(0xFFF5DEDA),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    // === 수정한 내용: 연속 탭으로 Google 인증 요청이 중복 실행되는 것을 방지한다 ===
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'https://morak.app',
          queryParams: {'prompt': 'select_account'},
        );
      } else {
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
        if (webClientId == null) throw '환경변수에 GOOGLE_WEB_CLIENT_ID가 없습니다.';

        final googleSignIn = GoogleSignIn.instance;

        if (!_isGoogleInitialized) {
          await googleSignIn.initialize(serverClientId: webClientId);
          _isGoogleInitialized = true;
        }

        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await googleSignIn
            .authenticate();
        if (googleUser == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) throw 'ID 토큰을 찾을 수 없어요.';

        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );

        // === 수정한 내용: 완료 안내는 전역 인증 흐름에서 새 화면에 표시해 중복 toast를 제거한다 ===
      }
    } catch (e) {
      // === 수정한 내용: Google 로그인 취소는 SDK 오류 코드로 판별하여 일반 실패와 구분한다 ===
      if (!(e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('로그인하지 못했습니다. 다시 시도해 주세요.')));
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    '모락',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _introData.length,
                    itemBuilder: (context, index) {
                      final intro = _introData[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 20,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight - 40).clamp(
                                  0.0,
                                  double.infinity,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 240,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: intro.accent,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Transform.rotate(
                                          angle: -0.10,
                                          child: Container(
                                            width: 152,
                                            height: 144,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                            child: Icon(
                                              intro.icon,
                                              size: 72,
                                              color: AppConstants.primaryColor,
                                            ),
                                          ),
                                        ),
                                        const Positioned(
                                          right: 22,
                                          top: 18,
                                          child: Icon(
                                            Icons.auto_awesome_rounded,
                                            color: AppConstants.primaryColor,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    intro.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      height: 1.35,
                                      fontWeight: FontWeight.w800,
                                      color: AppConstants.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    intro.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.7,
                                      color: AppConstants.textBody,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _introData.length,
                    (index) => Semantics(
                      label: '앱 소개 ${index + 1}/${_introData.length}',
                      selected: _currentPage == index,
                      child: IconButton(
                        tooltip: '${index + 1}번째 소개',
                        onPressed: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _currentPage == index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppConstants.primaryColor
                                : AppConstants.secondaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Button(
                    text: 'Google로 시작하기',
                    onPressed: _isLoading ? null : _googleSignIn,
                    type: ButtonType.outlined,
                    color: AppConstants.cardBackground,
                    textColor: const Color(0xFF1F1F1F),
                    height: 52,
                    borderRadius: 28,
                    borderSide: const BorderSide(color: Color(0xFF747775)),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: AppConstants.scaffoldBackground.withValues(alpha: 0.9),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

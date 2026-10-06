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

  // 🌟 앱 소개 데이터 (이미지 경로, 제목, 설명)
  final List<Map<String, String>> _introData = [
    {
      'image': 'assets/images/intro1.png',
      'title': '모락모락 피어나는 추억 ☁️',
      'desc': '소중한 사람들과의 만남을\n쉽고 깔끔하게 기록해 보세요.',
    },
    {
      'image': 'assets/images/intro2.png',
      'title': '함께 완성하는 앨범 📸',
      'desc': '모임원들이 다같이 사진을 올리고\n대표 사진을 정할 수 있어요.',
    },
    {
      'image': 'assets/images/intro3.png',
      'title': '출석률과 통계까지 📊',
      'desc': '누가 가장 모임에 잘 나오는지\n재미있는 통계도 확인해 보세요!',
    },
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
                const SizedBox(height: 40),

                // 🌟 1. 앱 소개 슬라이드 영역
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _introData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Image.asset(
                                _introData[index]['image']!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppConstants.borderColor,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 64,
                                          color: AppConstants.textCaption,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 48),
                            Text(
                              _introData[index]['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppConstants.textTitle,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _introData[index]['desc']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppConstants.textBody,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 🌟 2. 슬라이드 인디케이터 (점 3개)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _introData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppConstants.primaryColor
                            : AppConstants.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // 🌟 3. 하단 구글 로그인 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Button(
                    text: 'Google로 시작하기',
                    onPressed: _isLoading ? null : _googleSignIn,
                    color: AppConstants.cardBackground,
                    textColor: AppConstants.textTitle,
                    type: ButtonType.outlined, // 외곽선 있는 버튼으로 깔끔하게
                    // 🌟 구글 공식 로고 이미지 (assets/images/google_logo.png 필요)
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 4. 로딩 화면 페이드 인/아웃 효과
          IgnorePointer(
            ignoring: !_isLoading, // 로딩 중이 아닐 땐 터치 통과
            child: AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300), // 0.3초
              child: Container(
                color: AppConstants.scaffoldBackground.withOpacity(0.9),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

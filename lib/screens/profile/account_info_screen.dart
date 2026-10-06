import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../models/account_info.dart';
import '../../repositories/user_repository.dart';

// === 수정한 내용: 마이페이지에서 실제 인증 계정의 로그인 방식·이메일·가입일을 확인할 수 있게 한다 ===
class AccountInfoScreen extends StatefulWidget {
  final UserRepository? repository;
  const AccountInfoScreen({super.key, this.repository});
  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late final Stream<AccountInfo?> _account;
  @override
  void initState() {
    super.initState();
    _account = (widget.repository ?? locator<UserRepository>())
        .watchAccountInfo();
  }

  String _date(DateTime? date) {
    if (date == null) return '확인할 수 없음';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppConstants.scaffoldBackground,
    appBar: AppBar(
      title: const Text(
        '계정 정보',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppConstants.textTitle,
        ),
      ),
      backgroundColor: AppConstants.scaffoldBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: StreamBuilder<AccountInfo?>(
      stream: _account,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('계정 정보를 불러오지 못했습니다. 다시 열어 주세요.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snapshot.data;
        if (info == null) return const Center(child: Text('로그인이 필요합니다.'));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _item('현재 로그인 방식', info.loginMethod),
            _item('로그인 계정 / 이메일', info.email ?? '확인할 수 없음'),
            _item('가입일', _date(info.createdAt)),
            _item('최근 로그인일', _date(info.lastSignInAt)),
          ],
        );
      },
    ),
  );
  // === 수정한 내용: 항목명은 볼드 텍스트로 분리하고 실제 값만 입력창 형태로 표시한다 ===
  Widget _item(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppConstants.textTitle,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppConstants.cardBackground,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppConstants.borderColor),
            ),
          ),
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 15, color: AppConstants.textBody),
          ),
        ),
      ],
    ),
  );
}

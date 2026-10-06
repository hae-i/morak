import 'package:flutter/material.dart';

import 'common_button.dart';

// === 수정한 내용: 조회 실패를 무한 로딩과 구분하고 기존 버튼 스타일로 재시도를 제공한다 ===
class RequestErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const RequestErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Button(text: '다시 시도', onPressed: onRetry, width: 200),
        ],
      ),
    ),
  );
}

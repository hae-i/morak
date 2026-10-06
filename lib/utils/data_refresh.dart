import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_provider.dart';

// === 수정한 내용: 저장이나 삭제가 성공한 경우에만 홈 피드를 갱신하여 오래된 기록 표시를 방지한다 ===
void refreshHomeFeed(BuildContext context) {
  context
      .findAncestorWidgetOfExactType<UncontrolledProviderScope>()
      ?.container
      .invalidate(feedProvider);
}

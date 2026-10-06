import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 서버 반환 행 제한보다 많은 기록도 확인된 전체 건수까지 읽어 통계와 참석자 누락을 막는다 ===
Future<List<Map<String, dynamic>>> readAllRows(
  Future<PostgrestResponse<List<Map<String, dynamic>>>> Function(
    int offset,
    int pageSize,
  )
  fetch, {
  int pageSize = 200,
}) async {
  final rows = <Map<String, dynamic>>[];
  int? total;
  while (true) {
    final response = await fetch(
      rows.length,
      pageSize,
    ).timeout(const Duration(seconds: 20));
    total ??= response.count;
    if (response.data.isEmpty && rows.length < total) {
      throw StateError('조회 도중 데이터가 변경되었습니다. 다시 시도해 주세요.');
    }
    rows.addAll(response.data);
    if (rows.length >= total) return rows;
  }
}

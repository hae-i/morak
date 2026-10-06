import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: Android 프로세스 종료 뒤 사진을 같은 계정과 작업에서만 명시적으로 복구한다 ===
class ImageSelectionRecovery {
  static final instance = ImageSelectionRecovery();
  static const _key = 'morak.image_selection';
  static const _recoveredKey = 'morak.recovered_image_selections';
  final Future<LostDataResponse> Function() retrieve;
  final Future<SharedPreferences> Function() preferences;
  Future<void>? _initialization;
  ImageSelectionRecovery({
    Future<LostDataResponse> Function()? retrieve,
    Future<SharedPreferences> Function()? preferences,
  }) : retrieve = retrieve ?? (() => ImagePicker().retrieveLostData()),
       preferences = preferences ?? SharedPreferences.getInstance;

  Future<void> initialize() =>
      _initialization ??= _initialize().catchError((Object error) {
        _initialization = null;
        throw error;
      });
  Future<void> _initialize() async {
    final prefs = await preferences();
    final metadata = _read(prefs);
    final lost = await retrieve();
    if (lost.exception != null) {
      await prefs.remove(_key);
      throw StateError('사진 선택을 복구하지 못했습니다.');
    }
    if (lost.files?.isNotEmpty == true && metadata != null) {
      metadata['paths'] = lost.files!.map((file) => file.path).toList();
      final saved = _saved(prefs)
        ..removeWhere(
          (entry) =>
              entry['userId'] == metadata['userId'] &&
              entry['target'] == metadata['target'],
        );
      saved.add(metadata);
      if (!await prefs.setString(_recoveredKey, jsonEncode(saved))) {
        throw StateError('복구 정보를 저장하지 못했습니다.');
      }
      await prefs.remove(_key);
    }
  }

  List<Map<String, dynamic>> _saved(SharedPreferences prefs) {
    try {
      final entries =
          jsonDecode(prefs.getString(_recoveredKey) ?? '[]') as List;
      return entries
          .whereType<Map<String, dynamic>>()
          .where(
            (entry) =>
                DateTime.now().difference(
                  DateTime.parse(entry['created'] as String),
                ) <=
                const Duration(days: 1),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _read(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final created = DateTime.parse(data['created'] as String);
      if (DateTime.now().difference(created) > const Duration(days: 1)) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<List<XFile>> recover(String userId, String target) async {
    await initialize();
    final data = _saved(await preferences())
        .where(
          (entry) => entry['userId'] == userId && entry['target'] == target,
        )
        .firstOrNull;
    if (data == null) return [];
    return (data['paths'] as List? ?? [])
        .whereType<String>()
        .map(XFile.new)
        .toList();
  }

  Future<void> begin(String userId, String target) async {
    final prefs = await preferences();
    if (!await prefs.setString(
      _key,
      jsonEncode({
        'userId': userId,
        'target': target,
        'created': DateTime.now().toIso8601String(),
      }),
    )) {
      throw StateError('사진 선택 정보를 기록하지 못했습니다.');
    }
  }

  Future<void> clear(String userId, String target) async {
    final prefs = await preferences();
    final data = _read(prefs);
    if (data?['userId'] == userId && data?['target'] == target) {
      await prefs.remove(_key);
    }
    final saved = _saved(prefs)
      ..removeWhere(
        (entry) => entry['userId'] == userId && entry['target'] == target,
      );
    await prefs.setString(_recoveredKey, jsonEncode(saved));
  }
}

// === 수정한 내용: 각 picker에서 동일 복구 절차를 사용하고 복구 사진을 사용자 동의 없이 업로드하지 않는다 ===
Future<List<XFile>> pickImagesWithRecovery({
  required BuildContext context,
  required ImagePicker picker,
  required String target,
  bool multiple = false,
  double maxWidth = 512,
  double maxHeight = 512,
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final enabled =
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      userId != null;
  final recovery = ImageSelectionRecovery.instance;
  try {
    if (enabled) {
      final restored = await recovery.recover(userId, target);
      if (!context.mounted ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return [];
      }
      if (restored.isNotEmpty) {
        final use = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('사진 선택 복구'),
            content: Text('앱이 종료되기 전에 선택한 사진 ${restored.length}장을 복구할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('다시 선택'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('복구'),
              ),
            ],
          ),
        );
        if (!context.mounted ||
            Supabase.instance.client.auth.currentUser?.id != userId) {
          return [];
        }
        if (use == null) return [];
        if (use) {
          await recovery.clear(userId, target);
          // === 수정한 내용: 복구 정보 정리 중 계정이 바뀌어도 이전 계정 사진을 반환하지 않는다 ===
          if (!context.mounted ||
              Supabase.instance.client.auth.currentUser?.id != userId) {
            return [];
          }
          return multiple ? restored : [restored.first];
        }
      }
      await recovery.begin(userId, target);
    }
    final files = multiple
        ? await picker.pickMultiImage(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            imageQuality: 80,
          )
        : [
            await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              imageQuality: 80,
            ),
          ].whereType<XFile>().toList();
    if (enabled) await recovery.clear(userId, target);
    if (!context.mounted ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return [];
    }
    return files;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다. 다시 시도해 주세요.')),
      );
    }
    return [];
  }
}

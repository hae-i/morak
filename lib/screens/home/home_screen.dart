import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../models/group_model.dart';
import '../../providers/auth_user_provider.dart';
import '../../providers/home_provider.dart';
import '../../repositories/group_repository.dart';
import '../../services/private_photos.dart';
import '../../widgets/common/request_error_view.dart';
import '../group/group_create_screen.dart';
import '../group/group_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onGroupCreated;
  const HomeScreen({super.key, this.onGroupCreated});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<GroupModel> _groups = [];
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;
  String? _userId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final generation = ++_generation;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await locator<GroupRepository>().fetchMyGroups();
      if (!mounted ||
          generation != _generation ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      setState(
        () => _groups = rows.map((row) => row['group'] as GroupModel).toList(),
      );
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(feedProvider);
    await _loadGroups();
  }

  Future<void> _openGroup(GroupModel group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
    );
    if (mounted) await _refresh();
  }

  Future<void> _createGroup() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
    );
    if (mounted && changed == true) {
      widget.onGroupCreated?.call();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) {
      if (!next.hasValue || next.value == _userId) return;
      _userId = next.value;
      setState(() => _groups = []);
      _loadGroups();
    });
    final memories = ref.watch(feedProvider);
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text('모락', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppConstants.scaffoldBackground,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Text(
              '우리의 만남이\n추억으로 쌓이는 곳',
              style: TextStyle(
                fontSize: 28,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '함께한 사람들, 다녀온 곳, 그날의 사진.\n오늘의 만남도 모락에 남겨 보세요.',
              style: TextStyle(color: AppConstants.textBody, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createGroup,
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('새로운 모임 만들기'),
            ),
            const SizedBox(height: 32),
            const Text(
              '나의 추억 서랍',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '모임을 열어 만남을 기록하고 함께한 시간을 돌아봐요.',
              style: TextStyle(color: AppConstants.textBody, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_failed)
              RequestErrorView(message: '모임을 불러오지 못했습니다.', onRetry: _loadGroups)
            else if (_groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: AppConstants.primaryColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '아직 추억 서랍이 비어 있어요.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '첫 모임을 만들거나 친구에게 받은\n초대 링크로 참여해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppConstants.textBody,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final group in _groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: Text(
                        group.themeEmoji ?? '☁️',
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        '만남 기록 · 사진첩 · 함께한 시간',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openGroup(group),
                    ),
                  ),
                ),
            memories.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(feedProvider),
                child: const Text('마지막 만남 다시 불러오기'),
              ),
              data: (records) {
                if (records.isEmpty) return const SizedBox.shrink();
                final record = records.first;
                final group = record.group;
                if (group == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      '마지막으로 함께한 날',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openGroup(group),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (record.photos.isNotEmpty)
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: PrivatePhotoImage(
                                  imageUrl: record.photos.first,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const ColoredBox(
                                    color: AppConstants.secondaryColor,
                                  ),
                                  errorWidget: (_, _, _) => const Center(
                                    child: Icon(Icons.photo_outlined),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppConstants.textBody,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    record.title ?? '함께한 만남',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${record.date.split('T').first} · ${record.attendanceMemberIds.toSet().length}명이 함께했어요',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppConstants.textBody,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

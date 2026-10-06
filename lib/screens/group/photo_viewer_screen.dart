// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/meetup_model.dart';
import '../../models/member_model.dart';
import 'meetup_detail_screen.dart';
import '../../locator.dart';
import '../../repositories/meetup_repository.dart';
import '../../services/photo_saver.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final MeetupModel? meetup;
  final List<MemberModel> groupMembers;
  final Color activeColor;
  final PhotoSaver? photoSaver;
  final List<MeetupModel>? photoMeetups;

  const PhotoViewerScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    this.meetup,
    required this.groupMembers,
    required this.activeColor,
    this.photoSaver,
    this.photoMeetups,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showBars = true;
  bool _isOpeningRecord = false;
  bool _isSavingPhoto = false;
  // === 수정한 내용: 여러 기록의 사진을 넘긴 경우 현재 사진에 연결된 기록을 연다 ===
  MeetupModel? get _currentMeetup =>
      widget.photoMeetups != null && _currentIndex < widget.photoMeetups!.length
      ? widget.photoMeetups![_currentIndex]
      : widget.meetup;

  // === 수정한 내용: 현재 사진을 실제 갤러리에 저장하고 중복 요청과 폐기된 화면의 메시지를 차단한다 ===
  Future<void> _savePhoto() async {
    if (_isSavingPhoto || widget.imageUrls.isEmpty) return;
    final url = widget.imageUrls[_currentIndex];
    setState(() => _isSavingPhoto = true);
    try {
      await (widget.photoSaver ?? PhotoSaver()).save(url);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('갤러리에 사진을 저장했습니다.')));
    } on PhotoSaveException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  // === 수정한 내용: 사진 화면에서 기록을 다시 열 때 최신 값을 조회하여 편집 전 데이터의 재사용을 막는다 ===
  Future<void> _openRecord() async {
    final meetup = _currentMeetup;
    if (_isOpeningRecord || meetup == null) return;
    _isOpeningRecord = true;
    try {
      final latest = await locator<MeetupRepository>().fetchMeetup(meetup.id);
      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MeetupDetailScreen(
            meetup: latest,
            groupMembers: widget.groupMembers,
            activeColor: widget.activeColor,
          ),
        ),
      );
      // === 수정한 내용: 기존 뒤로가기 목적지를 유지하면서 기록 변경이 끝난 뒤 부모의 갱신을 이어 간다 ===
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기록을 불러오지 못했습니다. 삭제 여부와 연결 상태를 확인해 주세요.'),
          ),
        );
      }
    } finally {
      _isOpeningRecord = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.transparent),
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleBars,
            behavior: HitTestBehavior.opaque,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: PrivatePhotoImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                );
              },
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _showBars ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 12,
                left: 12,
                right: 12,
              ),
              color: Colors.black.withOpacity(0.55),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.imageUrls.isEmpty ? 0 : _currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            bottom: _showBars ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 16,
                left: 20,
                right: 20,
              ),
              color: Colors.black.withOpacity(0.55),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentMeetup != null)
                    TextButton.icon(
                      onPressed: _openRecord,
                      icon: const Icon(
                        Icons.event_note_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        '기록 보러가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  TextButton.icon(
                    onPressed: _isSavingPhoto || widget.imageUrls.isEmpty
                        ? null
                        : _savePhoto,
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      _isSavingPhoto ? '저장 중' : '저장',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

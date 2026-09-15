import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeetupCreateScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? initialMeetup;

  const MeetupCreateScreen({super.key, required this.groupId, this.initialMeetup});

  @override
  State<MeetupCreateScreen> createState() => _MeetupCreateScreenState();
}

class _MeetupCreateScreenState extends State<MeetupCreateScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _menuController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // 👈 출석 체크를 위한 상태 변수들
  List<Map<String, dynamic>> _members = []; // 전체 멤버 리스트
  final Set<String> _selectedMemberIds = {}; // 선택된 멤버들의 ID 모음

  @override
  void initState() {
    super.initState();
    _loadMembers(); // 화면 켜지면 멤버 목록부터 불러오기!

    if (widget.initialMeetup != null) {
      _locationController.text = widget.initialMeetup!['location'] ?? '';
      _menuController.text = widget.initialMeetup!['menu'] ?? '';
      if (widget.initialMeetup!['meet_date'] != null) {
        _selectedDate = DateTime.parse(widget.initialMeetup!['meet_date']);
      }
      _loadExistingAttendances(); // 수정 모드면 기존 참석자 불러오기!
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  // DB에서 이 모임의 멤버들 긁어오기
  Future<void> _loadMembers() async {
    final data = await Supabase.instance.client
        .from('group_members')
        .select()
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() {
        _members = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  // 수정 모드일 때: 기존에 출석 체크됐던 멤버들 불러오기
  Future<void> _loadExistingAttendances() async {
    final data = await Supabase.instance.client
        .from('attendances')
        .select('member_id')
        .eq('meetup_id', widget.initialMeetup!['id']);

    if (mounted) {
      setState(() {
        for (var row in data) {
          _selectedMemberIds.add(row['member_id'].toString());
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8A80)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveMeetup() async {
    final location = _locationController.text.trim();
    final menu = _menuController.text.trim();

    if (location.isEmpty && menu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소나 메뉴 중 최소 하나는 입력해 주세요! ☁️')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final meetupData = {
        'group_id': widget.groupId,
        'meet_date': _selectedDate.toIso8601String(),
        'location': location.isNotEmpty ? location : null,
        'menu': menu.isNotEmpty ? menu : null,
      };

      String currentMeetupId;

      if (widget.initialMeetup == null) {
        // 1. 새 만남 기록 저장하고, 방금 생성된 데이터의 ID(.select().single()) 가져오기!
        final insertedData = await Supabase.instance.client
            .from('meetups')
            .insert(meetupData)
            .select('id')
            .single();
        currentMeetupId = insertedData['id'];
      } else {
        // 2. 기존 만남 기록 수정하기
        currentMeetupId = widget.initialMeetup!['id'];
        await Supabase.instance.client.from('meetups').update(meetupData).eq('id', currentMeetupId);

        // 수정할 땐 기존 출석 기록 싹 날려버리고 새로 쓸 준비!
        await Supabase.instance.client.from('attendances').delete().eq('meetup_id', currentMeetupId);
      }

      // 3. 선택된 참석자가 있다면 출석부(attendances)에 데이터 꽂아넣기!
      if (_selectedMemberIds.isNotEmpty) {
        final attendanceData = _selectedMemberIds.map((memberId) => {
          'meetup_id': currentMeetupId,
          'member_id': memberId,
        }).toList();

        await Supabase.instance.client.from('attendances').insert(attendanceData);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialMeetup == null ? '🎉 만남 기록과 출석부가 저장되었어요!' : '🎉 기록과 출석부가 수정되었어요!'),
            backgroundColor: const Color(0xFFFF8A80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialMeetup != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditMode ? '기록 수정하기 ✏️' : '기록 남기기 ✏️'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 만난 날짜
            _buildSectionTitle('만난 날짜'),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.year}. ${_selectedDate.month.toString().padLeft(2, '0')}. ${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w500),
                    ),
                    Icon(Icons.calendar_month_rounded, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 참석자 선택 (새로 추가된 핵심 UI! ✨)
            _buildSectionTitle('누가 참석했나요?'),
            const SizedBox(height: 12),
            _members.isEmpty
                ? Text('등록된 멤버가 없어요.\n이전 화면에서 멤버를 먼저 추가해주세요!', style: TextStyle(color: Colors.grey[500]))
                : Wrap(
              spacing: 8.0, // 가로 간격
              runSpacing: 8.0, // 줄바꿈 시 세로 간격
              children: _members.map((member) {
                final memberId = member['id'].toString();
                final isSelected = _selectedMemberIds.contains(memberId);

                return FilterChip(
                  label: Text(member['display_name']),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedMemberIds.add(memberId);
                      } else {
                        _selectedMemberIds.remove(memberId);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFFF8A80),
                  checkmarkColor: Colors.white,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 3. 장소 & 메뉴
            _buildSectionTitle('장소'),
            const SizedBox(height: 12),
            _buildTextField(_locationController, '예) 구로몬 시장, 도톤보리'),
            const SizedBox(height: 24),

            _buildSectionTitle('메뉴'),
            const SizedBox(height: 12),
            _buildTextField(_menuController, '예) 오코노미야키, 생맥주 🍻'),
            const SizedBox(height: 40),

            // 4. 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMeetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A80),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  isEditMode ? '수정 완료' : '기록 완료',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
        ),
      ),
    );
  }
}
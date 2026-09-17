import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 🌟 1. 공통 소제목 (Section Title)
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }
}

// 🌟 2. 공통 텍스트 입력창 (Custom TextField)
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
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

// 🌟 3. 공통 프로필 아바타 (사진/이모지 + 카메라 뱃지)
class EditableAvatar extends StatelessWidget {
  final double radius;
  final XFile? localImage;
  final String? networkImageUrl;
  final String? emoji;
  final Color backgroundColor;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const EditableAvatar({
    super.key,
    required this.radius,
    this.localImage,
    this.networkImageUrl,
    this.emoji,
    required this.backgroundColor,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = localImage != null || networkImageUrl != null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: localImage != null
                ? ClipOval(
                    child: kIsWeb
                        ? Image.network(localImage!.path, fit: BoxFit.cover)
                        : Image.file(File(localImage!.path), fit: BoxFit.cover),
                  )
                : (networkImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            networkImageUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (emoji != null
                            ? Center(
                                child: Text(
                                  emoji!,
                                  style: TextStyle(fontSize: radius * 0.8),
                                ),
                              )
                            : Icon(
                                fallbackIcon,
                                size: radius * 0.8,
                                color: Colors.grey[400],
                              ))),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(radius * 0.15),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A80),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: radius * 0.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

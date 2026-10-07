// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';

// 🌟 1. 공통 소제목 (Section Title)
class SectionTitle extends StatelessWidget {
  final String title;
  final bool isRequired;
  final bool isOptional;

  const SectionTitle(
    this.title, {
    super.key,
    this.isRequired = false,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppConstants.textTitle,
          ),
        ),
        if (isRequired || isOptional)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 1),
            child: Text(
              isRequired ? '*' : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isRequired
                    ? AppConstants.dangerColor
                    : AppConstants.textCaption,
              ),
            ),
          ),
      ],
    );
  }
}

// 🌟 2. 공통 텍스트 입력창 (Custom TextField)
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final EdgeInsetsGeometry contentPadding;
  final bool isDense;
  final ValueChanged<String>? onSubmitted;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.errorText,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    this.isDense = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onSubmitted: onSubmitted,
          textInputAction: onSubmitted == null ? null : TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            isDense: isDense,
            hintStyle: const TextStyle(
              color: AppConstants.textCaption,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppConstants.dividerColor,
            contentPadding: contentPadding,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: errorText != null
                    ? AppConstants.dangerColor
                    : AppConstants.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: errorText != null
                    ? AppConstants.dangerColor
                    : AppConstants.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppConstants.dangerColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
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
              border: Border.all(color: AppConstants.borderColor, width: 1),
            ),
            child: localImage != null
                ? ClipOval(
                    child: kIsWeb
                        ? Image.network(localImage!.path, fit: BoxFit.cover)
                        : Image.file(File(localImage!.path), fit: BoxFit.cover),
                  )
                : (networkImageUrl != null
                      ? ClipOval(
                          child: PrivatePhotoImage(
                            imageUrl: networkImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(
                                  color: AppConstants.primaryColor,
                                ),
                            errorWidget: (context, url, error) => Icon(
                              fallbackIcon,
                              size: radius * 0.8,
                              color: AppConstants.textCaption,
                            ),
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
                                color: AppConstants.borderColor,
                              ))),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(radius * 0.15),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppConstants.cardBackground,
                  width: 2,
                ),
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

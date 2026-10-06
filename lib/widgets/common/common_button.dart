import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

enum ButtonType { filled, outlined, text }

class Button extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final double width;
  final double height;

  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.filled,
    this.color,
    this.textColor,
    this.icon,
    this.width = double.infinity,
    this.height = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppConstants.primaryColor;
    final effectiveTextColor =
        textColor ??
        (type == ButtonType.filled ? Colors.white : AppConstants.textTitle);

    final overlayStyle = WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return effectiveTextColor.withOpacity(0.1);
      }
      return null;
    });

    if (type == ButtonType.outlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(effectiveTextColor),
            side: WidgetStateProperty.all(
              const BorderSide(color: AppConstants.borderColor),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            overlayColor: overlayStyle,
            splashFactory: NoSplash.splashFactory,
          ),
          child: _buildChild(),
        ),
      );
    }

    // 기본은 Filled Button
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(effectiveColor),
          foregroundColor: WidgetStateProperty.all(effectiveTextColor),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          overlayColor: overlayStyle,
          splashFactory: NoSplash.splashFactory,
        ),
        child: _buildChild(),
      ),
    );
  }

  Widget _buildChild() {
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

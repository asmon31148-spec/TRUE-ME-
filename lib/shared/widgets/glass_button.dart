import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

class GlassButton extends StatelessWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final double? width;
  final double height;
  final Widget? icon;
  final Color? surfaceColor;
  final Color? borderColor;
  final double? borderRadius;

  const GlassButton({
    super.key,
    this.child,
    this.text,
    required this.onPressed,
    this.isPrimary = false,
    this.width,
    this.height = 52.0,
    this.icon,
    this.surfaceColor,
    this.borderColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveChild = child ?? Text(text ?? '');
    final radius = borderRadius ?? 12.0;

    if (isPrimary) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: surfaceColor ?? AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: AppTypography.fontFamily,
                ),
                child: effectiveChild,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: surfaceColor ?? AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          side: BorderSide(color: borderColor ?? AppColors.border, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontFamily: AppTypography.fontFamily,
              ),
              child: effectiveChild,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/liquid_glass_theme.dart';
import '../../app/theme/typography.dart';

class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double height;
  final Widget? icon;
  final Color? surfaceColor;
  final Color? borderColor;
  final String? tooltip;

  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isPrimary = false,
    this.borderRadius = LiquidGlassTheme.radiusPill,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.width,
    this.height = 48,
    this.icon,
    this.surfaceColor,
    this.borderColor,
    this.tooltip,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final baseDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      color: widget.surfaceColor,
      gradient: widget.surfaceColor != null
          ? null
          : widget.isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(_isPressed ? 0.22 : 0.12),
                    Colors.white.withOpacity(_isPressed ? 0.12 : 0.05),
                  ],
                ),
      border: Border.all(
        color: widget.borderColor ??
            (widget.isPrimary
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(_isPressed ? 0.45 : 0.25)),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: widget.isPrimary
              ? AppColors.primary.withOpacity(0.35)
              : Colors.black.withOpacity(0.2),
          blurRadius: widget.isPrimary ? 18 : 12,
          offset: const Offset(0, 6),
        ),
      ],
    );

    Widget buttonBody = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LiquidGlassTheme.blurSubtle,
            sigmaY: LiquidGlassTheme.blurSubtle,
          ),
          child: GestureDetector(
            onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: baseDecoration,
              child: Center(
                child: widget.icon != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.icon!,
                          const SizedBox(width: 8),
                          widget.child,
                        ],
                      )
                    : widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: buttonBody,
      );
    }

    return buttonBody;
  }
}

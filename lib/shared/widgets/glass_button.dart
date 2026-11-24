import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/liquid_glass_theme.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';
import 'glass_card.dart';

/// Tactile Liquid Glass Action Button.
///
/// Features:
/// - 44px+ ergonomic touch target compliance
/// - Tactile spring scale-down to 0.97 on press + light haptic feedback
/// - Primary mode: Electric Indigo gradient with specular highlight
/// - Secondary / Glass mode: Frosted Liquid Glass with 1px light-refraction border
class GlassButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double? width;
  final double height;
  final Widget? icon;
  final Color? surfaceColor;
  final Color? borderColor;
  final Gradient? customGradient;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enableHaptic;

  const GlassButton({
    super.key,
    this.child,
    this.text,
    required this.onPressed,
    this.isPrimary = false,
    this.isLoading = false,
    this.width,
    this.height = 52.0,
    this.icon,
    this.surfaceColor,
    this.borderColor,
    this.customGradient,
    this.borderRadius = 14.0,
    this.padding,
    this.enableHaptic = true,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      if (widget.enableHaptic) {
        HapticFeedback.lightImpact();
      }
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    final Widget labelWidget = widget.child ??
        Text(
          widget.text ?? '',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontFamily: AppTypography.fontFamily,
            color: widget.isPrimary
                ? Colors.white
                : (isDark ? LiquidGlassTheme.darkTextPrimary : LiquidGlassTheme.lightTextPrimary),
          ),
        );

    final Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isPrimary ? Colors.white : LiquidGlassTheme.electricIndigo,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 8),
              ],
              labelWidget,
            ],
          );

    // Primary Electric Indigo Button
    if (widget.isPrimary) {
      final primaryGradient = widget.customGradient ??
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Electric Indigo
              Color(0xFF4F46E5), // Deep Indigo
            ],
          );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? _handleTapDown : null,
        onTapUp: isEnabled ? _handleTapUp : null,
        onTapCancel: isEnabled ? _handleTapCancel : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          ),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: CustomPaint(
              foregroundPainter: SpecularBorderPainter(
                borderRadius: widget.borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.35),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderWidth: 1.0,
              ),
              child: Container(
                width: widget.width ?? double.infinity,
                height: widget.height.clamp(LiquidGlassTheme.minTouchTarget, 100.0),
                padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: LiquidGlassTheme.electricIndigo.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    // Secondary Frosted Liquid Glass Button
    final Color secondaryFill = widget.surfaceColor ??
        (isDark ? LiquidGlassTheme.darkGlassFill : LiquidGlassTheme.lightGlassFill);

    final Gradient secondaryBorder = widget.borderColor != null
        ? LinearGradient(colors: [widget.borderColor!, widget.borderColor!])
        : (isDark
            ? LiquidGlassTheme.darkSpecularBorder
            : LiquidGlassTheme.lightSpecularBorder);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.center,
          child: child,
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: CustomPaint(
            foregroundPainter: SpecularBorderPainter(
              borderRadius: widget.borderRadius,
              gradient: secondaryBorder,
              borderWidth: 1.0,
            ),
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height.clamp(LiquidGlassTheme.minTouchTarget, 100.0),
              padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: secondaryFill,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: isDark
                    ? LiquidGlassTheme.darkGlassShadow()
                    : LiquidGlassTheme.lightGlassShadow(),
              ),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

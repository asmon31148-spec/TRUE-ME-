import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/liquid_glass_theme.dart';

/// Reusable Apple-grade Liquid Glass Container.
///
/// Features:
/// - 1px GPU-accelerated specular border gradient (light refraction)
/// - Tactile micro-interaction: spring scale-down to 0.97 + light haptic feedback
/// - 60fps performance optimization: blur is strictly selective (defaults to false for lists)
/// - Fully theme-adaptive across Dark Obsidian and Light Silk canvases
class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? surfaceColor;
  final Color? borderColor;
  final Gradient? surfaceGradient;
  final Gradient? borderGradient;
  final bool enableBlur;
  final double blurSigma;
  final bool enableHaptic;
  final double pressScale;
  final Color? glowColor;
  final List<BoxShadow>? customShadows;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.borderRadius = LiquidGlassTheme.cardRadius,
    this.onTap,
    this.onLongPress,
    this.surfaceColor,
    this.borderColor,
    this.surfaceGradient,
    this.borderGradient,
    this.enableBlur = false,
    this.blurSigma = LiquidGlassTheme.standardBlurSigma,
    this.enableHaptic = true,
    this.pressScale = 0.97,
    this.glowColor,
    this.customShadows,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressScale != widget.pressScale) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.pressScale,
      ).animate(
        CurvedAnimation(
          parent: _pressController,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutBack,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      if (widget.enableHaptic) {
        HapticFeedback.lightImpact();
      }
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // Resolve surface fill
    final Color effectiveFill = widget.surfaceColor ??
        (isDark ? LiquidGlassTheme.darkGlassFill : LiquidGlassTheme.lightGlassFill);

    // Resolve specular border gradient
    final Gradient effectiveBorderGradient = widget.borderGradient ??
        (widget.borderColor != null
            ? LinearGradient(colors: [widget.borderColor!, widget.borderColor!])
            : (isDark
                ? LiquidGlassTheme.darkSpecularBorder
                : LiquidGlassTheme.lightSpecularBorder));

    // Resolve elevation shadows
    final List<BoxShadow> effectiveShadows = widget.customShadows ??
        (isDark
            ? LiquidGlassTheme.darkGlassShadow(glowColor: widget.glowColor)
            : LiquidGlassTheme.lightGlassShadow(glowColor: widget.glowColor));

    Widget innerContent = CustomPaint(
      foregroundPainter: SpecularBorderPainter(
        borderRadius: widget.borderRadius,
        gradient: effectiveBorderGradient,
        borderWidth: 1.0,
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.surfaceGradient == null ? effectiveFill : null,
          gradient: widget.surfaceGradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: widget.child,
      ),
    );

    if (widget.enableBlur) {
      innerContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: innerContent,
        ),
      );
    }

    Widget cardBody = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: effectiveShadows,
      ),
      child: innerContent,
    );

    // Outer margin
    if (widget.margin != null) {
      cardBody = Padding(
        padding: widget.margin!,
        child: cardBody,
      );
    }

    // Interactive tactile feedback
    if (widget.onTap != null || widget.onLongPress != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          ),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}

/// GPU-accelerated specular border painter.
/// Draws a pixel-perfect 1px gradient stroke matching the RRect contour.
class SpecularBorderPainter extends CustomPainter {
  final double borderRadius;
  final Gradient gradient;
  final double borderWidth;

  const SpecularBorderPainter({
    required this.borderRadius,
    required this.gradient,
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant SpecularBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.gradient != gradient ||
        oldDelegate.borderWidth != borderWidth;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';
import 'true_me_illustrations.dart';

/// Warm Milk Ivory & Lavender Silk Ribbon Canvas.
/// Zero GPU blur overhead; smoothly adapts to Dark Mode.
class TrueMeAmbientBackground extends StatelessWidget {
  final Widget child;
  final bool intenseLavender;

  const TrueMeAmbientBackground({
    super.key,
    required this.child,
    this.intenseLavender = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.bgColor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: SilkRibbonBackgroundPainter(
                isDark: isDark,
                intense: intenseLavender,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Smooth staggered entrance reveal (fade + gentle upward slide) respecting OS reduce-motion.
class TrueMeEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double offsetY;

  const TrueMeEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 14,
  });

  @override
  State<TrueMeEntrance> createState() => _TrueMeEntranceState();
}

class _TrueMeEntranceState extends State<TrueMeEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.offsetY, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    if (widget.delayMs <= 0) {
      _ctrl.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Elevated milky-white card with soft atmospheric lavender shadow & zero harsh grey borders.
class TrueMeCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final bool showShadow;
  final double? width;
  final double? height;

  const TrueMeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0.0,
    this.showShadow = true,
    this.width,
    this.height,
  });

  @override
  State<TrueMeCard> createState() => _TrueMeCardState();
}

class _TrueMeCardState extends State<TrueMeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final isDark = context.isDarkMode;

    final effectiveBorderWidth = widget.borderWidth > 0
        ? widget.borderWidth
        : (widget.borderColor != null ? 1.5 : (isDark ? 0.8 : 0.0));

    final decoration = BoxDecoration(
      color: widget.gradient == null
          ? (widget.color ?? (isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.94)))
          : null,
      gradient: widget.gradient,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      border: effectiveBorderWidth > 0
          ? Border.all(
              color: widget.borderColor ??
                  (isDark ? AppColors.darkBorder : const Color(0x80ECE8F5)),
              width: effectiveBorderWidth,
            )
          : null,
      boxShadow: widget.showShadow ? context.cardShadow : null,
    );

    final box = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: decoration,
      child: widget.child,
    );

    if (!interactive) return box;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: (_pressed && !disableAnim) ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: box,
      ),
    );
  }
}

/// Primary pill CTA matching the luminous glossy indigo gradient buttons in the references.
class TrueMePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double height;
  final double? width;
  final double borderRadius;

  const TrueMePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.height = 54,
    this.width,
    this.borderRadius = 28,
  });

  @override
  State<TrueMePrimaryButton> createState() => _TrueMePrimaryButtonState();
}

class _TrueMePrimaryButtonState extends State<TrueMePrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: (_pressed && !disableAnim) ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.55,
          child: Container(
            width: widget.width ?? double.infinity,
            height: widget.height.clamp(44.0, 64.0),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: AppColors.indigoButtonGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leadingIcon != null) ...[
                        widget.leadingIcon!,
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (widget.trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        widget.trailingIcon!,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Editorial Section Header with Serif title and optional "View All ->" link.
class TrueMeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const TrueMeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sectionHeading.copyWith(color: context.textPrimary),
          ),
        ),
        if (actionLabel != null && onActionTap != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onActionTap!();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: context.accentColor),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Smooth Animated Gradient Circular Progress Gauge.
class TrueMeCircularRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final List<Color> gradientColors;
  final Widget? center;

  const TrueMeCircularRing({
    super.key,
    required this.progress,
    this.size = 110,
    this.strokeWidth = 10,
    this.gradientColors = const [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF2DD4BF),
      Color(0xFF6366F1),
    ],
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final clamped = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: disableAnim ? clamped : 0.0, end: clamped),
      duration: Duration(milliseconds: disableAnim ? 0 : 750),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _CircularRingPainter(
                  progress: animatedVal,
                  strokeWidth: strokeWidth,
                  trackColor: isDark
                      ? AppColors.darkBorder
                      : const Color(0xFFE7E3F5),
                  colors: gradientColors,
                ),
              ),
              if (center != null) center!,
            ],
          ),
        );
      },
    );
  }
}

class _CircularRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final List<Color> colors;

  _CircularRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    final sweepAngle = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor;
}

/// Clean Borderless Milky-Lavender Tonal Pill Action Button / Badge.
class TrueMeTonalPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  const TrueMeTonalPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.milkyFill;
    final fg = foregroundColor ?? context.accentColor;

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return inner;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      borderRadius: BorderRadius.circular(24),
      child: inner,
    );
  }
}

/// Soft Circular Icon Button matching top bars, zoom controls & audio skip buttons.
class TrueMeCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  const TrueMeCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
    this.backgroundColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final btn = InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.94)),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E2A5C).withValues(alpha: isDark ? 0.24 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: size * 0.48,
          color: iconColor ?? context.textPrimary,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// User Monogram Avatar with soft pastel indigo gradient ring.
class TrueMeAvatar extends StatelessWidget {
  final String name;
  final double size;
  final VoidCallback? onTap;

  const TrueMeAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    final avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB7B4FA), Color(0xFF5B5CE6)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.isDarkMode ? AppColors.darkSurface : const Color(0xFFEEEDFE),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: AppTypography.serifFallbacks,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: context.isDarkMode ? AppColors.darkAccent : AppColors.accent,
          ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: avatar,
    );
  }
}

/// Editorial Top Header Bar aligned with Reference Images.
class TrueMeTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool centerTitle;

  const TrueMeTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (onBack != null)
            SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onBack!();
                },
                borderRadius: BorderRadius.circular(22),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: context.textPrimary,
                ),
              ),
            )
          else if (centerTitle && trailing != null)
            const SizedBox(width: 44),
          Expanded(
            child: Text(
              title,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.screenTitle.copyWith(
                fontSize: 22.5,
                color: context.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (centerTitle && onBack != null)
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';

/// Soft Ivory & Lavender canvas with lightweight corner pastel washes.
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
              painter: _AmbientCornerPainter(
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

class _AmbientCornerPainter extends CustomPainter {
  final bool isDark;
  final bool intense;

  _AmbientCornerPainter({required this.isDark, required this.intense});

  @override
  void paint(Canvas canvas, Size size) {
    final topRightCenter = Offset(size.width * 0.92, size.height * 0.06);
    final bottomLeftCenter = Offset(size.width * 0.08, size.height * 0.88);
    final midRightCenter = Offset(size.width * 0.96, size.height * 0.56);

    final topAlpha = isDark ? (intense ? 0.16 : 0.10) : (intense ? 0.55 : 0.36);
    final bottomAlpha = isDark ? (intense ? 0.12 : 0.08) : (intense ? 0.48 : 0.30);

    final topPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF4F46E5) : const Color(0xFFD8D2FC))
              .withValues(alpha: topAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: topRightCenter, radius: size.width * 0.65));

    final bottomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF312E81) : const Color(0xFFE0DCFB))
              .withValues(alpha: bottomAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: bottomLeftCenter, radius: size.width * 0.72));

    canvas.drawCircle(topRightCenter, size.width * 0.65, topPaint);
    canvas.drawCircle(bottomLeftCenter, size.width * 0.72, bottomPaint);

    if (intense) {
      final midPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            (isDark ? const Color(0xFF6366F1) : const Color(0xFFE6E0FF))
                .withValues(alpha: isDark ? 0.10 : 0.38),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: midRightCenter, radius: size.width * 0.55));
      canvas.drawCircle(midRightCenter, size.width * 0.55, midPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientCornerPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.intense != intense;
}

/// Elevated soft white/ivory card with calm lavender hairline border & tactile press scale.
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
    this.borderRadius = 20,
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1.0,
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

    final decoration = BoxDecoration(
      color: widget.gradient == null ? (widget.color ?? context.surfaceColor) : null,
      gradient: widget.gradient,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      border: Border.all(
        color: widget.borderColor ??
            (isDark ? AppColors.darkBorder : const Color(0xFFEAE6F5)),
        width: widget.borderWidth,
      ),
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
        scale: (_pressed && !disableAnim) ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: box,
      ),
    );
  }
}

/// Primary pill action button matching the soft indigo gradient CTAs in the references.
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
    this.height = 52,
    this.width,
    this.borderRadius = 26,
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
        scale: (_pressed && !disableAnim) ? 0.975 : 1.0,
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
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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

/// Editorial Section Header with Serif title and optional "View All ->" pill/link.
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

/// Smooth Gradient Circular Progress Gauge (Exam Readiness & Home Mini Progress).
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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CircularRingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              trackColor: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFEAE7F6),
              colors: gradientColors,
            ),
          ),
          if (center != null) center!,
        ],
      ),
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

/// Clean Tonal Pill Action Button or Badge.
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
    final isDark = context.isDarkMode;
    final bg = backgroundColor ??
        (isDark ? AppColors.darkAccentWash : AppColors.accentWash);
    final fg = foregroundColor ?? context.accentColor;

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
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
      borderRadius: BorderRadius.circular(22),
      child: inner,
    );
  }
}

/// Circular Icon Button used cleanly in top bars across all reference screens.
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
              (isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.92)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE7E2F4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E2A5C).withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA5B4FC), Color(0xFF5B5CE6)],
        ),
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

/// Top Header Bar aligned with Reference Images (Back arrow + Serif Title + Trailing widget).
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
                fontSize: 22,
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

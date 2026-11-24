import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/liquid_glass_theme.dart';
import '../../app/theme/theme_provider.dart';
import 'glass_card.dart';

/// Floating Frosted Liquid Glass Navigation Bar.
///
/// Features:
/// - 12px Backdrop blur with selective ClipRect
/// - 1px bottom specular hairline border
/// - Clean typography and 44px+ touch-accessible actions
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final Widget? titleWidget;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.titleWidget,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final Color barColor = isDark
        ? LiquidGlassTheme.darkCanvas.withOpacity(0.75)
        : LiquidGlassTheme.lightCanvas.withOpacity(0.80);

    final Gradient specularBorder = isDark
        ? LiquidGlassTheme.darkSpecularBorder
        : LiquidGlassTheme.lightSpecularBorder;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassTheme.standardBlurSigma,
          sigmaY: LiquidGlassTheme.standardBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: centerTitle,
                leading: leading,
                actions: actions,
                title: titleWidget ??
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? LiquidGlassTheme.darkTextPrimary
                            : LiquidGlassTheme.lightTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                bottom: bottom,
              ),
              // 1px Specular bottom border
              CustomPaint(
                size: const Size(double.infinity, 1.0),
                painter: _BottomSpecularBorderPainter(gradient: specularBorder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSpecularBorderPainter extends CustomPainter {
  final Gradient gradient;

  const _BottomSpecularBorderPainter({required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _BottomSpecularBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient;
  }
}

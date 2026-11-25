import 'package:flutter/material.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';

/// Clean Editorial Navigation Bar with soft Ivory/Surface tint & bottom hairline.
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
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0) + 1.0,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgColor.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 0.8),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: centerTitle,
        leading: leading,
        actions: actions,
        title: titleWidget ??
            Text(
              title,
              style: AppTypography.screenTitle.copyWith(
                fontSize: 21,
                color: context.textPrimary,
              ),
            ),
        bottom: bottom,
      ),
    );
  }
}

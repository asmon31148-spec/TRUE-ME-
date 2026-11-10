import 'package:flutter/material.dart';
import '../../app/theme/theme_provider.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.bgColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      leading: leading,
      actions: actions,
      bottom: bottom,
      shape: Border(
        bottom: BorderSide(color: context.borderColor, width: 1),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';

/// Primary Pill Button: Full width, 52 px high, signature indigo gradient, white text.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.accentColor;
    final fg = foregroundColor ?? Colors.white;
    final enabled = !isLoading && onPressed != null;

    return SizedBox(
      width: width ?? double.infinity,
      height: (height ?? 52).clamp(44.0, 68.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: backgroundColor == null && enabled ? AppColors.indigoButtonGradient : null,
          color: backgroundColor != null
              ? (enabled ? bg : bg.withValues(alpha: 0.5))
              : (enabled ? null : bg.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(26),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: fg,
            disabledBackgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: isLoading
              ? null
              : (onPressed == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    }),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary Pill Button: 52 px high, borderless milky-lavender fill for calm secondary CTAs.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double? height;
  final double? width;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: width ?? double.infinity,
      height: (height ?? 52).clamp(44.0, 68.0),
      child: Material(
        color: enabled ? context.milkyFill : context.milkyFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: enabled ? context.accentColor : context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded pastel icon container used across Quick Access, Library, Account & Practice.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.iconSize = 20,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.accentTint,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: color ?? context.accentColor,
      ),
    );
  }
}

/// Card: Soft borderless surface fill, radius 20, subtle atmospheric shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showChevron = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardContent = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.94)),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkBorder, width: 0.8) : null,
        boxShadow: context.cardShadow,
      ),
      child: showChevron
          ? Row(
              children: [
                Expanded(child: child),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
              ],
            )
          : child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: BorderRadius.circular(20),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// List Row: 58 px high minimum, borderless elevated card fill, pastel badge on left, title/subtitle, chevron on right.
class AppListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: isDark ? Border.all(color: AppColors.darkBorder, width: 0.8) : null,
          boxShadow: context.cardShadow,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.secondary.copyWith(color: context.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Input: Label above, crisp white card fill, soft lavender border, radius 14.
class AppInput extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final bool autofocus;
  final TextInputType keyboardType;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const AppInput({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15.5, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}

/// Pill Filter Chip: Borderless milky-lavender unselected; glossy Indigo selected.
class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.indigoButtonGradient : null,
          color: isSelected ? null : context.milkyFill,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Progress Bar: Smooth 7 px rounded track with Indigo fill.
class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0

  const AppProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: context.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
        ),
      ),
    );
  }
}

/// Empty State: Soft pastel icon container, helpful text, pill CTA button.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: context.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(icon: icon, size: 58, iconSize: 28),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 210,
                child: AppPrimaryButton(
                  label: buttonLabel,
                  onPressed: onButtonPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

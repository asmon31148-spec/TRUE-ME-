import 'package:flutter/material.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/theme/typography.dart';

class AiThinkingIndicator extends StatelessWidget {
  final String label;

  const AiThinkingIndicator({
    super.key,
    this.label = 'Sage is thinking...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: context.surfaceColor,
        border: Border.all(
          color: context.borderColor,
          width: 1.0,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

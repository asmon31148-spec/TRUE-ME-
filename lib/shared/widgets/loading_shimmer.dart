import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/theme/colors.dart';

class GlassShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const GlassShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLighter.withOpacity(0.4),
      highlightColor: Colors.white.withOpacity(0.12),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
      ),
    );
  }
}

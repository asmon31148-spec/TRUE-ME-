import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/explainer_script_model.dart';

class SceneAnimator extends StatelessWidget {
  final ExplainerSceneModel scene;
  final bool isPlaying;

  const SceneAnimator({
    super.key,
    required this.scene,
    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      surfaceGradient: const LinearGradient(
        colors: [Color(0x331E1B4B), Color(0x1A0F172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scene Title
          Text(
            'SCENE ${scene.sceneNumber}: ${scene.title.toUpperCase()}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.accentCyan,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.2, end: 0),
          const SizedBox(height: 28),

          // Central Visual Stage based on Animation Type
          _buildVisualStage(context)
              .animate(target: isPlaying ? 1 : 0)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
              ),
          const SizedBox(height: 32),

          // Synchronized Narration Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '"${scene.narrationText}"',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildVisualStage(BuildContext context) {
    switch (scene.animationType) {
      case AnimationType.diagram:
        return _buildDiagramView();
      case AnimationType.formula:
        return _buildFormulaView();
      case AnimationType.flowchart:
        return _buildFlowchartView();
      case AnimationType.bulletReveal:
        return _buildBulletView();
    }
  }

  Widget _buildDiagramView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: scene.elements.take(3).map((element) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.2),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Text(
            element,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormulaView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.functions, color: AppColors.accentCyan, size: 32),
          const SizedBox(height: 8),
          Text(
            scene.elements.isNotEmpty ? scene.elements.first : 'A · v = λ · v',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowchartView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMiniStep('Input'),
        const Icon(Icons.arrow_forward, color: AppColors.accentCyan, size: 18),
        _buildMiniStep('Process'),
        const Icon(Icons.arrow_forward, color: AppColors.accentCyan, size: 18),
        _buildMiniStep('Verify'),
      ],
    );
  }

  Widget _buildMiniStep(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  Widget _buildBulletView() {
    return Column(
      children: scene.elements.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(e, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

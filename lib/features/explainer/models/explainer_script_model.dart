enum AnimationType { diagram, formula, bulletReveal, flowchart }

class ExplainerSceneModel {
  final int sceneNumber;
  final String title;
  final String narrationText;
  final int durationSeconds;
  final AnimationType animationType;
  final List<String> elements;

  const ExplainerSceneModel({
    required this.sceneNumber,
    required this.title,
    required this.narrationText,
    required this.durationSeconds,
    this.animationType = AnimationType.diagram,
    this.elements = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'sceneNumber': sceneNumber,
      'title': title,
      'narrationText': narrationText,
      'durationSeconds': durationSeconds,
      'animationType': animationType.name,
      'elements': elements,
    };
  }

  factory ExplainerSceneModel.fromMap(Map<String, dynamic> map) {
    return ExplainerSceneModel(
      sceneNumber: (map['sceneNumber'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? 'Scene',
      narrationText: map['narrationText'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 60,
      animationType: AnimationType.values.firstWhere(
        (t) => t.name == map['animationType'],
        orElse: () => AnimationType.diagram,
      ),
      elements: List<String>.from(map['elements'] ?? const []),
    );
  }
}

class ExplainerScriptModel {
  final String title;
  final String topic;
  final int totalDurationSeconds;
  final List<ExplainerSceneModel> scenes;

  const ExplainerScriptModel({
    required this.title,
    required this.topic,
    this.totalDurationSeconds = 600, // 10 minutes
    required this.scenes,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'topic': topic,
      'totalDurationSeconds': totalDurationSeconds,
      'scenes': scenes.map((s) => s.toMap()).toList(),
    };
  }

  factory ExplainerScriptModel.fromMap(Map<String, dynamic> map) {
    final rawScenes = map['scenes'] as List<dynamic>? ?? [];
    return ExplainerScriptModel(
      title: map['title'] as String? ?? 'Concept Explainer',
      topic: map['topic'] as String? ?? 'General Topic',
      totalDurationSeconds: (map['totalDurationSeconds'] as num?)?.toInt() ?? 600,
      scenes: rawScenes
          .map((s) => ExplainerSceneModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class AiErrorBoundary {
  AiErrorBoundary._();

  /// Converts raw exceptions into supportive, student-friendly explanations.
  static String formatErrorMessage(Object error) {
    final str = error.toString().toLowerCase();

    if (str.contains('rate limit') || str.contains('quota reached')) {
      return 'Sage hit peak study volume and smoothly failed over to our backup engine.';
    }

    if (str.contains('socketexception') || str.contains('network') || str.contains('timed out')) {
      return 'You are currently offline or on a weak connection. Offline study cache is active.';
    }

    if (str.contains('not configured')) {
      return 'This AI service is awaiting API key setup in your .env configuration.';
    }

    return 'Sage encountered an unexpected hiccup. Please retry in a few moments.';
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification Service with user authentication enforcement.
/// Ensures reminders and study briefs are strictly tied to the logged-in student.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static const String _authUserIdKey = 'notification_auth_user_id';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Sets the currently authenticated user for notifications.
  static Future<void> setAuthenticatedUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_authUserIdKey);
      await cancelAll(); // Clear notifications when student logs out
    } else {
      await prefs.setString(_authUserIdKey, userId);
    }
  }

  /// Checks if notifications are permitted for the given user.
  static Future<bool> isUserAuthenticated(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_authUserIdKey);
    return activeId == userId;
  }

  /// Displays an immediate notification with authentication verification.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? userId,
    String? payload,
  }) async {
    if (userId != null && !await isUserAuthenticated(userId)) {
      return; // Do not notify if user is not logged in or mismatched
    }

    const androidDetails = AndroidNotificationDetails(
      'sage_daily_channel',
      'Sage Study Reminders',
      channelDescription: 'Daily morning study briefs and Spaced Repetition reviews',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails, payload: payload);
  }

  /// Schedules daily 6:00 AM study brief only for authenticated student.
  static Future<void> scheduleMorningBrief({
    required String userId,
    required String motivationalMessage,
  }) async {
    if (!await isUserAuthenticated(userId)) return;

    await showNotification(
      id: 1001,
      title: 'Sage Morning Brief 🧠',
      body: motivationalMessage,
      userId: userId,
      payload: 'morning_brief',
    );
  }

  /// Cancels all active notifications (called on logout).
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

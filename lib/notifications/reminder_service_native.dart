import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/age_label.dart';
import '../domain/baby.dart';
import 'reminder_planner.dart';

/// Schedules the user's photo reminders as local notifications on the phone.
/// Nothing leaves the device and no server is involved.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fall back to UTC; reminders still fire, possibly at a shifted hour.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Only used by the web app.
  Future<void> addToCalendar(Baby baby) async {}

  /// Asks the user for notification permission. Returns whether it is granted.
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  /// Whether the phone currently lets this app show notifications.
  Future<bool> notificationsAllowed() async {
    await _init();
    if (Platform.isIOS) {
      final o = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return o?.isEnabled ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  /// Shows a notification right now, so the parent can see reminders work.
  Future<void> sendTest(String babyName) async {
    await _init();
    await _plugin.show(
      id: 0,
      title: "Time for $babyName's photo",
      body: 'This is a test reminder.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'photo_reminders',
          'Photo reminders',
          channelDescription: 'Reminds you to take the next baby photo',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Replaces all scheduled reminders with a fresh rolling window for [babies].
  /// [photoDatesFor] says which days already have a photo (no reminder needed).
  Future<void> rescheduleAll(
    List<Baby> babies,
    Future<Set<DateTime>> Function(Baby) photoDatesFor,
  ) async {
    await _init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final perBaby = babies.isEmpty ? 0 : (60 ~/ babies.length).clamp(1, 30);
    var id = 1;
    for (final baby in babies) {
      final plan = planReminders(
        baby,
        now,
        photoDates: await photoDatesFor(baby),
        max: perBaby,
      );
      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: id++,
          title: "Time for ${baby.name}'s photo",
          body: ageLabel(baby.birth, r.photoDate),
          scheduledDate: tz.TZDateTime.from(r.when, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'photo_reminders',
              'Photo reminders',
              channelDescription: 'Reminds you to take the next baby photo',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Inexact is fine for a daily nudge and avoids the exact-alarm permission.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}

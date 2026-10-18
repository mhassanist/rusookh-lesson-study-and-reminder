import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/scheduler.dart';
import '../models/models.dart';

abstract class Reminders {
  Future<bool> requestPermission();

  /// Replaces all scheduled reminders based on the current cards.
  Future<void> reschedule(List<StudyCard> cards, {required bool enabled, required TimeOfDay time});
}

class NoopReminders implements Reminders {
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> reschedule(List<StudyCard> cards, {required bool enabled, required TimeOfDay time}) async {}
}

/// Schedules one notification per upcoming day that has due cards, with the
/// expected count in the body. Re-run whenever cards change.
class NotificationReminders implements Reminders {
  static const _daysAhead = 14;
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, falling back to UTC: $e');
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
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  @override
  Future<void> reschedule(List<StudyCard> cards, {required bool enabled, required TimeOfDay time}) async {
    await _plugin.cancelAll();
    if (!enabled || cards.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'review_reminders',
        'تذكير المراجعة',
        channelDescription: 'تذكير يومي بالأسئلة اللي عليها الدور',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    for (var d = 0; d < _daysAhead; d++) {
      final at = tz.TZDateTime(tz.local, now.year, now.month, now.day + d, time.hour, time.minute);
      if (at.isBefore(now)) continue;
      final count = cards.where((c) => Scheduler.isDue(c, at)).length;
      if (count == 0) continue;
      await _plugin.zonedSchedule(
        id: d,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'وقت المراجعة 🧠',
        body: 'عندك $count سؤال مستنيينك. حاول تفتكر قبل ما تشوف الإجابة!',
      );
    }
  }
}

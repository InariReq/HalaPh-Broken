import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:halaph/models/plan.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PlanNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _requestPermissions();

    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> schedulePlanReminders(TravelPlan plan) async {
    await initialize();
    await cancelPlanReminders(plan.id);

    final reminders = _buildReminders(plan);
    if (reminders.isEmpty) {
      debugPrint('Plan notifications: no future reminders for ${plan.id}');
      return;
    }

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.triggerAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'plan_reminders',
            'Plan reminders',
            channelDescription: 'Reminders for saved travel plan stops',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: plan.id,
      );
    }

    debugPrint(
      'Plan notifications: scheduled ${reminders.length} reminders for ${plan.id}',
    );
  }

  static Future<void> cancelPlanReminders(String planId) async {
    await initialize();

    for (var index = 0; index < 64; index++) {
      await _plugin.cancel(_notificationId(planId, index));
    }
  }

  static List<_PlanReminder> _buildReminders(TravelPlan plan) {
    final starts = <_PlanStopStart>[];

    for (final day in plan.itinerary) {
      for (final item in day.items) {
        final startsAt = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          item.startTime.hour,
          item.startTime.minute,
        );

        starts.add(
          _PlanStopStart(
            destinationName: item.destination.name.trim().isEmpty
                ? 'your destination'
                : item.destination.name.trim(),
            startsAt: startsAt,
          ),
        );
      }
    }

    starts.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final now = DateTime.now();
    final reminders = <_PlanReminder>[];

    for (var index = 0; index < starts.length && index < 64; index++) {
      final stop = starts[index];
      final reminderOffset =
          index == 0 ? const Duration(hours: 1) : const Duration(minutes: 30);
      final triggerAt = stop.startsAt.subtract(reminderOffset);

      if (!triggerAt.isAfter(now)) continue;

      final title = index == 0
          ? 'Upcoming trip: ${stop.destinationName}'
          : 'Next stop: ${stop.destinationName}';

      final body = index == 0
          ? 'Your first stop starts at ${_formatTime(stop.startsAt)}.'
          : 'Starts at ${_formatTime(stop.startsAt)}.';

      reminders.add(
        _PlanReminder(
          id: _notificationId(plan.id, index),
          title: title,
          body: body,
          triggerAt: triggerAt,
        ),
      );
    }

    return reminders;
  }

  static int _notificationId(String planId, int index) {
    var hash = 0;
    for (final codeUnit in planId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return (hash % 1000000) * 100 + index;
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }
}

class _PlanStopStart {
  final String destinationName;
  final DateTime startsAt;

  const _PlanStopStart({
    required this.destinationName,
    required this.startsAt,
  });
}

class _PlanReminder {
  final int id;
  final String title;
  final String body;
  final DateTime triggerAt;

  const _PlanReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.triggerAt,
  });
}

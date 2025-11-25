import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialiser tidszoner til scheduling
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 2. Android indstillinger
    // Vi bruger standard app ikonet ('@mipmap/launcher_icon')
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // 3. iOS indstillinger
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Samlet init
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Her kan vi håndtere hvis brugeren trykker på notifikationen
        print("Bruger trykkede på notifikation: ${response.payload}");
      },
    );
    
    // Opret kanal til Android (kræves for lyd/vibration)
    await _createNotificationChannel();
  }
  
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gendo_timer_channel', // id
      'Timer & Fokus', // title
      description: 'Notifikationer når tiden er gået', // description
      importance: Importance.max,
      playSound: true,
      // sound: RawResourceAndroidNotificationSound('alarm_sound'), // HVIS DU HAR CUSTOM LYD
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  // --- SEND STRAKS (Til Timer) ---
  Future<void> showTimerCompleteNotification({
    required String title, 
    required String body,
    bool isWorkSession = true
  }) async {
    await _notifications.show(
      0, // ID (0 for timer, vi overskriver bare)
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gendo_timer_channel',
          'Timer & Fokus',
          channelDescription: 'Notifikationer når tiden er gået',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          // sound: RawResourceAndroidNotificationSound('alarm_sound'), // HVIS DU HAR CUSTOM LYD
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBanner: true,
          // sound: 'alarm_sound.aiff', // HVIS DU HAR CUSTOM LYD PÅ IOS
        ),
      ),
      payload: isWorkSession ? 'work_complete' : 'break_complete',
    );
  }

  // --- SCHEDULE DEADLINE (Kl. 08:00 på dagen) ---
  Future<void> scheduleDeadlineNotification({
    required int id, // Brug opgavens hashcode som ID
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    // Sæt tidspunktet til kl 08:00 på deadline dagen
    final scheduledDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      8, // Klokken 8
      0,
    );

    // Hvis klokken allerede er passeret 8 i dag, så skip (eller planlæg til næste år, men her skipper vi bare)
    if (scheduledDate.isBefore(DateTime.now())) {
      return; 
    }

    await _notifications.zonedSchedule(
      id,
      'Deadline i dag! 📅',
      'Husk at få lavet: "$taskTitle"',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gendo_deadline_channel',
          'Deadlines',
          channelDescription: 'Påmindelser om deadlines',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
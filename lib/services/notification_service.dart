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
    // Hent enhedens tidszone sikkert
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback hvis tidszone fejler
      tz.setLocalLocation(tz.getLocation('Europe/Copenhagen'));
    }

    // 2. Android indstillinger
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
        print("Bruger trykkede på notifikation: ${response.payload}");
      },
    );
    
    // Opret kanaler til Android (vigtigt for lyd/prioritet)
    await _createNotificationChannels();
  }
  
  Future<void> _createNotificationChannels() async {
    // Kanal til Timer (Høj prioritet, lyd)
    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      'gendo_timer_channel', 
      'Timer & Fokus', 
      description: 'Notifikationer når tiden er gået',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('timer_sound'),
    );

    // Kanal til Opgaver (Deadlines)
    const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
      'gendo_task_channel', 
      'Opgave Påmindelser', 
      description: 'Påmindelser om deadlines',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('timer_sound'),
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(timerChannel);
      await androidPlugin.createNotificationChannel(taskChannel);
    }
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

  // --- VIS STRAKS (Bruges af Timer i ViewModel) ---
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gendo_timer_channel', // Matcher kanalen oprettet ovenfor
          'Timer & Fokus',
          channelDescription: 'Notifikationer når tiden er gået',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          sound: RawResourceAndroidNotificationSound('timer_sound'),
          fullScreenIntent: true,
        ),
        
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBanner: true,
          sound: 'timer_sound.wav', // Husk filendelse på iOS
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'timer_complete',
      
    );
  }

  // --- PLANLÆG OPGAVE (Bruges når opgaver oprettes/opdateres) ---
  Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Hvis datoen er i fortiden, undlad at planlægge
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Sætter tidspunktet til kl 08:00 hvis det er en "ren" dato (altså kl 00:00)
    // Dette sikrer at man ikke bliver vækket ved midnat hvis man bare vælger en dato.
    DateTime notificationTime = scheduledDate;
    if (scheduledDate.hour == 0 && scheduledDate.minute == 0) {
      notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        8, // Kl. 08:00 om morgenen
        0
      );
      // Hvis klokken allerede er over 8 i dag, så planlæg ikke (eller gør det med det samme?)
      // Her skipper vi bare for sikkerheds skyld hvis tidspunktet er passeret
      if (notificationTime.isBefore(DateTime.now())) return;
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gendo_task_channel',
          'Opgave Påmindelser',
          channelDescription: 'Påmindelser om deadlines',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('timer_sound'),
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBanner: true,
          sound: 'timer_sound.wav', // Husk filendelse på iOS
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  // --- PLANLÆG TIMER (Kritisk for baggrunds-timeren) ---
  Future<void> scheduleTimerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Sikkerhedstjek: Hvis tiden allerede er passeret, gør vi intet
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gendo_timer_channel', // Bruger den korrekte kanal til timer
          'Timer & Fokus',
          channelDescription: 'Notifikationer når tiden er gået',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('timer_sound'),
          // onGoing: true, // Kan overvejes, hvis den skal blive liggende
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBanner: true,
          interruptionLevel: InterruptionLevel.timeSensitive, // Vigtigt for iOS 15+
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Vækker telefonen
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // --- ANNULLER ALT (Bruges ved reset af timer) ---
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
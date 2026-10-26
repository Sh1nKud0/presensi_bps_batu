import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Jam kerja BPS Kota Batu
  static const int jamMasukHour = 7;
  static const int jamMasukMinute = 30;
  static const int jamPulangHour = 16;
  static const int jamPulangMinute = 0;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // Set default lokal ke WIB (Asia/Jakarta) - sesuaikan kalau lokasi BPS beda zona waktu
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);
  }

  Future<bool> mintaIzinNotifikasi() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    return granted ?? false;
  }

  Future<bool> tampilkanPengajuanAdmin(String title, String body) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    if (await android.requestNotificationsPermission() != true) return false;
    await _plugin.show(
      id: 100,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pengajuan_presensi',
          'Permintaan Persetujuan',
          channelDescription:
              'Pengajuan izin, sakit, susulan, dan pembatalan pulang',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    return true;
  }

  // Jadwalkan notifikasi berulang tiap hari kerja (Senin-Jumat)
  Future<void> jadwalkanPengingatHarian() async {
    // Hapus dulu jadwal lama supaya tidak duplikat
    await _plugin.cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'presensi_channel',
      'Pengingat Presensi',
      channelDescription: 'Notifikasi pengingat jam masuk dan pulang kerja',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    // id 1-5 untuk pengingat MASUK (Senin=1 ... Jumat=5)
    for (int hari = 1; hari <= 5; hari++) {
      await _plugin.zonedSchedule(
        id: hari, // id unik
        title: 'Waktunya Presensi Masuk!',
        body: 'Jangan lupa absen masuk sebelum jam 07:30 di lokasi BPS Kota Batu.',
        scheduledDate: _jadwalBerikutnya(hari, jamMasukHour, jamMasukMinute),
        notificationDetails: notifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    // id 11-15 untuk pengingat PULANG (Senin=11 ... Jumat=15)
    for (int hari = 1; hari <= 5; hari++) {
      await _plugin.zonedSchedule(
        id: 10 + hari,
        title: 'Jangan Lupa Absen Pulang',
        body: 'Sudah jam 16:00, jangan lupa lakukan presensi pulang sebelum meninggalkan kantor.',
        scheduledDate: _jadwalBerikutnya(hari, jamPulangHour, jamPulangMinute),
        notificationDetails: notifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // Hitung tanggal/jam terdekat untuk hari tertentu (1=Senin...5=Jumat) jam:menit tertentu
  tz.TZDateTime _jadwalBerikutnya(int targetWeekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Geser ke hari target (1=Senin...5=Jumat, DateTime.monday=1...DateTime.friday=5)
    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> batalkanSemuaPengingat() async {
    await _plugin.cancelAll();
  }
}

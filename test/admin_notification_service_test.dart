import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var allowed = true;
  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    allowed = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'requestNotificationsPermission' => allowed,
            _ => null,
          };
        });
    await NotificationService.instance.init();
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('Admin request alerts use a separate high priority channel without requesting alarms', () async {
    expect(
      await NotificationService.instance.tampilkanPengajuanAdmin(
        'Peserta mengajukan sakit',
        'Menunggu persetujuan admin.',
      ),
      true,
    );
    final show = calls.singleWhere((call) => call.method == 'show');
    expect(show.arguments['id'], 100);
    expect(show.arguments['title'], 'Peserta mengajukan sakit');
    expect(
      show.arguments['platformSpecifics']['channelId'],
      'pengajuan_presensi',
    );
    expect(
      calls.any((call) => call.method == 'requestExactAlarmsPermission'),
      false,
    );
  });

  test(
    'Denied notification permission does not attempt to show an alert',
    () async {
      allowed = false;
      expect(
        await NotificationService.instance.tampilkanPengajuanAdmin(
          'title',
          'body',
        ),
        false,
      );
      expect(calls.any((call) => call.method == 'show'), false);
    },
  );
}

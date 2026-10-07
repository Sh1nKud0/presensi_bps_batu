import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/services/daily_attendance.dart';

void main() {
  test('An empty working day permits attendance', () {
    expect(const DailyAttendance().blockReason, isNull);
  });
  test('Leave and correction requests block even before approval creates attendance', () {
    expect(
      const DailyAttendance(hasLeave: true).blockReason,
      contains('izin/sakit'),
    );
    expect(
      const DailyAttendance(hasCorrection: true).blockReason,
      contains('susulan'),
    );
  });
  test('Normal check-in permits one check-out, completed attendance blocks repeats', () {
    const masuk = DailyAttendance(
      attendance: {'status': 'hadir', 'jam_masuk': '2026-10-07T00:00:00Z'},
    );
    expect(masuk.checkedIn, isTrue);
    expect(masuk.checkedOut, isFalse);
    expect(masuk.blockReason, isNull);
    const lengkap = DailyAttendance(
      attendance: {
        'status': 'hadir',
        'jam_masuk': '2026-10-07T00:00:00Z',
        'jam_pulang': '2026-10-07T09:00:00Z',
      },
    );
    expect(lengkap.blockReason, contains('selesai'));
  });
  test('A request blocks check-out as well as check-in for its date', () {
    expect(
      const DailyAttendance(
        hasCorrection: true,
        attendance: {'status': 'hadir', 'jam_masuk': '2026-10-07T00:00:00Z'},
      ).blockReason,
      contains('susulan'),
    );
    expect(
      const DailyAttendance(
        hasLeave: true,
        attendance: {'status': 'hadir', 'jam_masuk': '2026-10-07T00:00:00Z'},
      ).blockReason,
      contains('izin/sakit'),
    );
  });
  test('Nonstandard or incomplete records must not be overwritten by normal attendance', () {
    for (final status in ['izin', 'sakit', 'dispensasi', 'alpha']) {
      expect(
        DailyAttendance(
          attendance: {'status': status, 'jam_masuk': '2026-10-07T00:00:00Z'},
        ).blockReason,
        isNotNull,
      );
    }
    expect(
      const DailyAttendance(attendance: {'status': 'hadir'}).blockReason,
      isNotNull,
    );
    expect(
      const DailyAttendance(attendance: {'jam_pulang': '2026-10-07T09:00:00Z'})
          .blockReason,
      isNotNull,
    );
  });
  test('Holidays block an otherwise empty day', () {
    expect(const DailyAttendance(holiday: true).blockReason, contains('libur'));
  });
  test('Date boundary uses WIB regardless of device timezone', () {
    expect(
      tanggalPresensiHariIni(DateTime.parse('2026-10-06T16:59:59Z')),
      '2026-10-06',
    );
    expect(
      tanggalPresensiHariIni(DateTime.parse('2026-10-06T17:00:00Z')),
      '2026-10-07',
    );
  });
}

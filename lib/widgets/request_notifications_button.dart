import 'glass_surface.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/request_notifications.dart';
import '../pages/admin_dashboard_page.dart';
import '../pages/izin_page.dart';
import '../pages/tabs/absen_susulan_page.dart';
import '../pages/pembatalan_pulang_page.dart';
import '../services/rekap_presensi.dart';

class RequestNotificationsButton extends StatefulWidget {
  final String userId;
  final bool isAdmin;
  final RequestNotificationsSource? repository;
  const RequestNotificationsButton({
    super.key,
    required this.userId,
    required this.isAdmin,
    this.repository,
  });

  @override
  State<RequestNotificationsButton> createState() =>
      _RequestNotificationsButtonState();
}

class _RequestNotificationsButtonState extends State<RequestNotificationsButton>
    with WidgetsBindingObserver {
  List<RequestNotification> _items = [];
  Set<String> _read = {};
  Timer? _timer;
  final _revision = ValueNotifier<int>(0);
  bool _opening = false;
  bool _loading = false;
  String? _error;
  String get _storageKey => 'request_notifications_read_${widget.userId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _revision.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final data =
          await (widget.repository ?? RequestNotificationsRepository(supabase))
              .load(widget.userId, widget.isAdmin);
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _items = data;
        _read = (preferences.getStringList(_storageKey) ?? []).toSet();
        _error = null;
      });
      _revision.value++;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Notifikasi belum dapat dimuat. Coba perbarui.',
        );
        _revision.value++;
      }
    } finally {
      _loading = false;
    }
  }

  Future<bool> _markRead(Iterable<RequestNotification> items) async {
    final updated = {..._read, ...items.map((item) => item.readKey)};
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _storageKey,
        updated.toList(),
      );
      if (!saved) throw StateError('Gagal menyimpan');
      if (mounted) {
        setState(() => _read = updated);
        _revision.value++;
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menandai notifikasi sebagai dibaca.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    await _refresh();
    if (!mounted) return;
    DateTime? selectedDay;
    final chosen = await showModalBottomSheet<RequestNotification>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _revision,
        builder: (context, revision, child) {
          final visible = filterNotificationsByDay(_items, selectedDay);
          final today = waktuWib(DateTime.now());
          final unread = visible
              .where((item) => !_read.contains(item.readKey))
              .length;
          return GlassSurface(
            blur: true,
            radius: 28,
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.82,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text(
                        'Notifikasi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        widget.isAdmin
                            ? 'Pengajuan menunggu persetujuan'
                            : 'Hasil pengajuan Anda',
                      ),
                      trailing: IconButton(
                        tooltip: 'Perbarui notifikasi',
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          await _refresh();
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua'),
                            selected: selectedDay == null,
                            onSelected: (_) {
                              selectedDay = null;
                              _revision.value++;
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Hari ini'),
                            selected:
                                selectedDay != null &&
                                tanggalRekap(selectedDay!) ==
                                    tanggalRekap(today),
                            onSelected: (_) {
                              selectedDay = today;
                              _revision.value++;
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Kemarin'),
                            selected:
                                selectedDay != null &&
                                tanggalRekap(selectedDay!) ==
                                    tanggalRekap(
                                      today.subtract(const Duration(days: 1)),
                                    ),
                            onSelected: (_) {
                              selectedDay = today.subtract(
                                const Duration(days: 1),
                              );
                              _revision.value++;
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              selectedDay == null
                                  ? 'Pilih tanggal'
                                  : '${selectedDay!.day}/${selectedDay!.month}/${selectedDay!.year}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: selectedDay ?? today,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(
                                  today.year,
                                  today.month,
                                  today.day,
                                ),
                              );
                              if (picked != null &&
                                  mounted &&
                                  sheetContext.mounted) {
                                selectedDay = picked;
                                _revision.value++;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await _markRead(visible);
                          },
                          child: Text(
                            selectedDay == null
                                ? 'Tandai semua dibaca'
                                : 'Tandai tanggal ini dibaca',
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                _error != null
                                    ? 'Ketuk tombol perbarui untuk mencoba lagi.'
                                    : selectedDay == null
                                    ? 'Belum ada notifikasi.'
                                    : 'Tidak ada notifikasi pada tanggal ini.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                final day = tanggalRekap(
                                  waktuWib(item.createdAt),
                                );
                                final showDay =
                                    index == 0 ||
                                    day !=
                                        tanggalRekap(
                                          waktuWib(
                                            visible[index - 1].createdAt,
                                          ),
                                        );
                                final isUnread = !_read.contains(item.readKey);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showDay)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          16,
                                          16,
                                          4,
                                        ),
                                        child: Text(
                                          day,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ListTile(
                                      leading: Icon(
                                        item.status == 'menunggu'
                                            ? Icons.pending_actions
                                            : item.status == 'disetujui'
                                            ? Icons.check_circle_outline
                                            : Icons.cancel_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      title: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${item.message}\n${jamRekap(item.createdAt.toIso8601String())} WIB',
                                      ),
                                      trailing: isUnread
                                          ? const Icon(Icons.circle, size: 8)
                                          : null,
                                      onTap: () async {
                                        if (await _markRead([item]) &&
                                            sheetContext.mounted) {
                                          Navigator.pop(sheetContext, item);
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    _opening = false;
    if (chosen == null || !mounted) return;
    final Widget page = widget.isAdmin
        ? AdminDashboardPage(
            initialTab: chosen.table == 'izin'
                ? 2
                : chosen.table == 'pembatalan_pulang'
                ? 5
                : 3,
          )
        : chosen.table == 'pembatalan_pulang'
        ? const PembatalanPulangPage()
        : chosen.table == 'izin'
        ? const IzinPage(initialTab: 1)
        : const AbsenSusulanPage(initialTab: 1);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !_read.contains(item.readKey)).length;
    return IconButton(
      tooltip: unread > 0 ? 'Notifikasi: $unread belum dibaca' : 'Notifikasi',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

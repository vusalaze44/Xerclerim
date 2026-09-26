import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../transactions/local_ledger.dart';
import 'cloud_backup.dart';
import 'google_backup_auth.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.ledger, required this.ownerUid,
    required this.firebaseReady, required this.onRefresh, this.email});
  final LocalLedger ledger;
  final String? ownerUid;
  final bool firebaseReady;
  final String? email;
  final Future<void> Function() onRefresh;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupInfo> backups = [];
  bool busy = false;
  String? message;
  CloudBackup get cloud => CloudBackup(FirebaseFirestore.instance);
  @override
  void initState() { super.initState(); if (widget.ownerUid != null) _load(); }

  Future<void> _load() async {
    try {
      final result = await cloud.list(widget.ownerUid!);
      if (mounted) setState(() { backups = result; message = null; });
    } catch (_) {
      if (mounted) setState(() => message = 'Yedəkləri görmək üçün internet bağlantısını və Firebase ayarlarını yoxlayın.');
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try { await action(); }
    catch (error) {
      if (mounted) setState(() => message = error is StateError
        ? 'Bu hesabda artıq lokal məlumat var. Əvvəl onu yedəkləyin.'
        : 'Əməliyyat tamamlanmadı. Bağlantını və hesabı yoxlayın.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _backup() => _perform(() async {
    final snapshot = await widget.ledger.exportSnapshot();
    final saved = await cloud.save(widget.ownerUid!, snapshot);
    await _load();
    if (mounted) setState(() => message = '${saved.recordCount} qeyd Google yedəyində təsdiqləndi.');
  });

  Future<void> _restore(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Yedək bərpa edilsin?'),
      content: const Text('Bu cihazda həmin Google hesabına aid lokal məlumat əvəz olunacaq. Davam etməzdən əvvəl cari məlumatı ayrıca yedəkləyin.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bərpa et')),
      ],
    ));
    if (confirmed != true) return;
    await _perform(() async {
      final snapshot = await cloud.fetch(widget.ownerUid!, backup.id);
      await widget.ledger.importSnapshot(snapshot, replaceExisting: true);
      await widget.onRefresh();
      if (mounted) setState(() => message = 'Yedək cihazda bərpa edildi.');
    });
  }

  Future<void> _importGuest() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Qonaq məlumatını köçür'),
      content: const Text('Bu cihazdakı əvvəlki hesabsız məlumatlar cari Google hesabının lokal sahəsinə kopyalanacaq. Hesabda artıq məlumat varsa köçürmə dayandırılır. Sonra ayrıca “İndi yedəklə” düyməsini basın.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Köçür')),
      ],
    ));
    if (confirmed != true) return;
    await _perform(() async {
      final guest = LocalLedger();
      try {
        if (!await guest.hasAnyData()) {
          if (mounted) setState(() => message = 'Köçürüləcək qonaq məlumatı yoxdur.');
          return;
        }
        final snapshot = await guest.exportSnapshot();
        await widget.ledger.importSnapshot(snapshot, replaceExisting: false);
        await widget.onRefresh();
        if (mounted) setState(() => message = 'Məlumat köçürüldü. İndi Google yedəyini yaradın.');
      } finally { await guest.close(); }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google yedəyi')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Yedək Google Drive faylı deyil: yalnız bu tətbiqin Firebase hesabında, sizin istifadəçi kodunuz altında saxlanır.'),
      const SizedBox(height: 12),
      if (!widget.firebaseReady) const Card(child: Padding(padding: EdgeInsets.all(16),
        child: Text('Firebase layihəsi hələ qoşulmayıb. Lokal məlumatlar cihazda qalır.')))
      else if (widget.ownerUid == null) ...[
        const Text('Google hesabına daxil olduqda hesab üçün ayrıca lokal məlumat sahəsi açılır. Qonaq məlumatlarını sonra əl ilə köçürə bilərsiniz.'),
        FilledButton.icon(onPressed: busy ? null : () => _perform(() async {
          await GoogleBackupAuth.signIn();
          if (mounted) Navigator.pop(context);
        }), icon: const Icon(Icons.login), label: const Text('Google ilə daxil ol')),
      ] else ...[
        Text('Hesab: ${widget.email ?? widget.ownerUid}', style: Theme.of(context).textTheme.bodySmall),
        FilledButton.icon(onPressed: busy ? null : _backup,
          icon: const Icon(Icons.cloud_upload), label: const Text('İndi yedəklə')),
        OutlinedButton.icon(onPressed: busy ? null : _importGuest,
          icon: const Icon(Icons.file_copy), label: const Text('Köhnə lokal məlumatı köçür')),
        TextButton.icon(onPressed: busy ? null : () => _perform(() async {
          await GoogleBackupAuth.signOut();
          if (mounted) Navigator.pop(context);
        }), icon: const Icon(Icons.logout), label: const Text('Hesabdan çıx')),
        const Divider(height: 32),
        Text('Son yedəklər', style: Theme.of(context).textTheme.titleLarge),
        if (backups.isEmpty) const Text('Hələ təsdiqlənmiş yedək yoxdur.'),
        for (final backup in backups) ListTile(
          leading: const Icon(Icons.cloud_done),
          title: Text('${backup.createdAt.toLocal().day}.${backup.createdAt.toLocal().month}.${backup.createdAt.toLocal().year}'),
          subtitle: Text('${backup.recordCount} qeyd'),
          trailing: TextButton(onPressed: busy ? null : () => _restore(backup),
            child: const Text('Bərpa et')),
        ),
      ],
      if (busy) const LinearProgressIndicator(),
      if (message != null) Padding(padding: const EdgeInsets.all(12), child: Text(message!)),
      const SizedBox(height: 12),
      const Text('Bulud yedəyi ucdan uca şifrələnmir; layihənin idarəçiləri məlumatlara texniki olaraq baxa bilər.'),
      const SizedBox(height: 8),
      const Text('Yedək yalnız “İndi yedəklə” seçiləndə yaradılır. İnternet olmadıqda lokal qeydlər işləyir; avtomatik sinxronizasiya bu mərhələdə yoxdur.'),
    ]),
  );
}

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/money.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key, required this.uid});
  final String uid;
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  List<QueryDocumentSnapshot<Map<String, dynamic>>> debts = [];
  bool busy = false;
  String? message;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final collection = FirebaseFirestore.instance.collection('debts');
      final results = await Future.wait([
        collection.where('lenderUid', isEqualTo: widget.uid).get(const GetOptions(source: Source.server)),
        collection.where('borrowerUid', isEqualTo: widget.uid).get(const GetOptions(source: Source.server)),
      ]);
      if (mounted) setState(() {
        debts = {for (final result in results) for (final doc in result.docs) doc.id: doc}.values.toList()
          ..sort((a, b) {
            final first = a.data()['createdAt'] as Timestamp?;
            final second = b.data()['createdAt'] as Timestamp?;
            return (second?.millisecondsSinceEpoch ?? 0).compareTo(first?.millisecondsSinceEpoch ?? 0);
          });
        message = null;
      });
    } catch (_) {
      if (mounted) setState(() => message = 'Sorğular açılmadı. İnterneti və Firebase ayarlarını yoxlayın.');
    }
  }

  String _id() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(24, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    if (busy) return;
    setState(() { busy = true; message = null; });
    try {
      await functions.httpsCallable(name).call(data);
      await _load();
      if (mounted) setState(() => message = 'Əməliyyat tamamlandı.');
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => message = 'Əməliyyat alınmadı: ${error.message ?? error.code}. App Check və hesab ayarlarını yoxlayın.');
    } catch (_) {
      if (mounted) setState(() => message = 'Əməliyyat alınmadı. İnterneti yoxlayın.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _request() async {
    final recipient = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var due = DateTime.now().add(const Duration(days: 30));
    try {
      final data = await showDialog<Map<String, dynamic>>(context: context, builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Dost borcu sorğusu'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Siz borc verənsiniz. Dostunuzun tətbiqdəki istifadəçi kodunu daxil edin.'),
            TextField(controller: recipient, decoration: const InputDecoration(labelText: 'Dostun istifadəçi kodu')),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Qeyd (istəyə bağlı)')),
            TextButton.icon(onPressed: () async {
              final value = await showDatePicker(context: dialog, initialDate: due,
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 5 * 365)));
              if (value != null) refresh(() => due = value);
            }, icon: const Icon(Icons.calendar_today), label: Text('Son tarix: ${due.day}.${due.month}.${due.year}')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Ləğv et')),
            FilledButton(onPressed: () {
              try {
                final qepik = Money.parseAzN(amount.text);
                if (qepik < 1 || qepik > 100000000 || recipient.text.trim().isEmpty || recipient.text.trim() == widget.uid) throw const FormatException();
                Navigator.pop(dialog, {'borrowerUid': recipient.text.trim(), 'amountQepik': qepik,
                  'dueAtMs': DateTime(due.year, due.month, due.day, 23, 59).millisecondsSinceEpoch,
                  if (note.text.trim().isNotEmpty) 'note': note.text.trim(), 'requestId': _id()});
              } catch (_) { ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content: Text('Dostun kodunu və düzgün məbləği daxil edin.'))); }
            }, child: const Text('Sorğu göndər')),
          ],
        ),
      ));
      if (data != null) await _call('createDebtRequest', data);
    } finally { recipient.dispose(); amount.dispose(); note.dispose(); }
  }

  Future<void> _pay(String debtId, int outstanding) async {
    final amount = TextEditingController();
    try {
      final value = await showDialog<int>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Ödəniş bildir'),
        content: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Məbləğ (AZN)', helperText: 'Qalıq: ${Money.format(outstanding)}')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Ləğv et')),
          FilledButton(onPressed: () {
            try {
              final qepik = Money.parseAzN(amount.text);
              if (qepik < 1 || qepik > outstanding) throw const FormatException();
              Navigator.pop(dialog, qepik);
            } catch (_) { ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content: Text('Qalığı aşmayan müsbət məbləğ daxil edin.'))); }
          }, child: const Text('Bildir'))],
      ));
      if (value != null) await _call('proposeDebtPayment', {'debtId': debtId, 'amountQepik': value, 'requestId': _id()});
    } finally { amount.dispose(); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dost borcları'), actions: [IconButton(onPressed: busy ? null : _load,
      icon: const Icon(Icons.refresh), tooltip: 'Yenilə')]),
    floatingActionButton: FloatingActionButton.extended(onPressed: busy ? null : _request,
      icon: const Icon(Icons.add), label: const Text('Sorğu göndər')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      const Text('Dostunuz da Google hesabı ilə daxil olmalı və öz istifadəçi kodunu sizinlə paylaşmalıdır. Borc yalnız onun təsdiqindən sonra aktiv olur.'),
      Card(child: ListTile(title: const Text('Mənim istifadəçi kodum'), subtitle: SelectableText(widget.uid),
        trailing: IconButton(icon: const Icon(Icons.copy), tooltip: 'Kopyala', onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.uid));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı.')));
        }))),
      if (busy) const LinearProgressIndicator(),
      if (message != null) Padding(padding: const EdgeInsets.all(12), child: Text(message!)),
      if (debts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Hələ dost borcu sorğusu yoxdur.')),
      for (final doc in debts) _debtCard(doc),
    ]),
  );

  Widget _debtCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final lender = data['lenderUid'] == widget.uid;
    final state = data['state'] as String? ?? '';
    final pending = data['pendingPayment'] as Map<String, dynamic>?;
    final outstanding = data['outstandingQepik'] as int? ?? 0;
    final due = (data['dueAt'] as Timestamp?)?.toDate();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lender ? 'Mənə borcludurlar' : 'Mən borcluyam', style: Theme.of(context).textTheme.titleMedium),
        Text('Qarşı tərəf: ${lender ? data['borrowerUid'] : data['lenderUid']}'),
        Text('Məbləğ: ${Money.format(data['principalQepik'] as int? ?? 0)} · Qalıq: ${Money.format(outstanding)}'),
        if (due != null) Text('Son tarix: ${due.day}.${due.month}.${due.year}'),
        if ((data['note'] as String? ?? '').isNotEmpty) Text(data['note'] as String),
        Text('Vəziyyət: ${switch (state) {'requested' => 'Təsdiq gözləyir', 'active' => 'Aktiv', 'closed' => 'Bağlanıb', 'rejected' => 'Rədd edilib', _ => state}}'),
        if (state == 'requested' && !lender) Wrap(spacing: 8, children: [
          TextButton(onPressed: busy ? null : () => _call('respondDebtRequest', {'debtId': doc.id, 'accept': false}), child: const Text('Rədd et')),
          FilledButton(onPressed: busy ? null : () => _call('respondDebtRequest', {'debtId': doc.id, 'accept': true}), child: const Text('Qəbul et')),
        ]),
        if (state == 'active' && !lender && pending == null)
          TextButton(onPressed: busy ? null : () => _pay(doc.id, outstanding), child: const Text('Ödəniş bildir')),
        if (pending != null) ...[
          Text('Ödəniş təsdiq gözləyir: ${Money.format(pending['amountQepik'] as int)}'),
          if (lender) Wrap(spacing: 8, children: [
            TextButton(onPressed: busy ? null : () => _call('respondDebtPayment',
              {'debtId': doc.id, 'paymentId': pending['id'], 'accept': false}), child: const Text('Etiraz et')),
            FilledButton(onPressed: busy ? null : () => _call('respondDebtPayment',
              {'debtId': doc.id, 'paymentId': pending['id'], 'accept': true}), child: const Text('Təsdiqlə')),
          ]),
        ],
      ],
    )));
  }
}

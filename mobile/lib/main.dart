import 'package:flutter/material.dart';
import 'core/money.dart';
import 'features/dashboard/summary.dart';
import 'features/transactions/local_ledger.dart';
import 'features/transactions/transaction.dart';
import 'features/loans/loans_page.dart';

void main() => runApp(const XerclerimApp());

class XerclerimApp extends StatelessWidget {
  const XerclerimApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Xərclərim', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff136f63), useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xff136f63), brightness: Brightness.dark, useMaterial3: true),
    home: const LedgerPage(),
  );
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final ledger = LocalLedger();
  List<LedgerEntry> entries = [];
  String? error;
  int selectedTab = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await ledger.all(); if (mounted) setState(() { entries = data; error = null; }); }
    catch (_) { if (mounted) setState(() => error = 'Məlumatlar açıla bilmədi.'); }
  }
  @override
  void dispose() { ledger.close(); super.dispose(); }

  Future<void> _add(EntryKind kind) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = kind == EntryKind.income ? 'Əməkhaqqı' : 'Ev bazarlığı';
    final categories = kind == EntryKind.income
        ? ['Əməkhaqqı', 'Əlavə gəlir', 'Digər']
        : ['Ev bazarlığı', 'Yanacaq', 'Kommunal', 'Təmir', 'Nəqliyyat', 'Digər'];
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(kind == EntryKind.income ? 'Gəlir əlavə et' : 'Xərc əlavə et'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
            DropdownButtonFormField<String>(initialValue: category, items: categories.map((item) =>
              DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) { if (value != null) refresh(() => category = value); }),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Qeyd (istəyə bağlı)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
            FilledButton(onPressed: () async {
              try {
                final qepik = Money.parseAzN(amount.text);
                if (qepik <= 0) throw const FormatException();
                await ledger.add(LedgerEntry(id: '${DateTime.now().microsecondsSinceEpoch}', kind: kind,
                  amountQepik: qepik, category: category, note: note.text.trim(), occurredAt: DateTime.now()));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Müsbət məbləği AZN ilə daxil edin.')));
              }
            }, child: const Text('Yadda saxla')),
          ],
        ),
      ));
    } finally { amount.dispose(); note.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    final summary = MonthlySummary.from(entries, DateTime.now());
    return Scaffold(
      bottomNavigationBar: NavigationBar(selectedIndex: selectedTab,
        onDestinationSelected: (value) => setState(() => selectedTab = value),
        destinations: const [NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Pul axını'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Kreditlər')]),
      body: selectedTab == 1 ? LoansPage(ledger: ledger) : Scaffold(
      appBar: AppBar(title: const Text('Xərclərim')),
      body: error != null ? Center(child: Text(error!)) : ListView(padding: const EdgeInsets.all(16), children: [
        Text('Bu ay', style: Theme.of(context).textTheme.headlineSmall),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gəlir: ${Money.format(summary.incomeQepik)}'),
          Text('Xərc: ${Money.format(summary.expenseQepik)}'),
          Text('Fərq: ${Money.format(summary.balanceQepik)}', style: Theme.of(context).textTheme.titleLarge),
        ]))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: () => _add(EntryKind.income), icon: const Icon(Icons.add), label: const Text('Gəlir')),
          OutlinedButton.icon(onPressed: () => _add(EntryKind.expense), icon: const Icon(Icons.remove), label: const Text('Xərc')),
        ]),
        const SizedBox(height: 16),
        Text('Əməliyyatlar', style: Theme.of(context).textTheme.titleLarge),
        if (entries.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('Hələ əməliyyat yoxdur.')),
        for (final entry in entries) ListTile(
          leading: Icon(entry.kind == EntryKind.income ? Icons.arrow_downward : Icons.arrow_upward),
          title: Text(entry.category), subtitle: Text(entry.note.isEmpty ? '${entry.occurredAt.day}.${entry.occurredAt.month}.${entry.occurredAt.year}' : entry.note),
          trailing: Text('${entry.kind == EntryKind.income ? '+' : '-'}${Money.format(entry.amountQepik)}'),
        ),
      ]),
      ),
    );
  }
}

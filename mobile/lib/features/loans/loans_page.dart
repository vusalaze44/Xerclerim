import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../transactions/local_ledger.dart';
import 'loan.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key, required this.ledger});
  final LocalLedger ledger;
  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  List<Loan> loans = [];
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final result = await widget.ledger.loans(); if (mounted) setState(() { loans = result; error = null; }); }
    catch (_) { if (mounted) setState(() => error = 'Kreditlər açıla bilmədi.'); }
  }
  Future<void> _add() async {
    final name = TextEditingController();
    final principal = TextEditingController();
    final rate = TextEditingController();
    final months = TextEditingController();
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    var firstDue = DateTime(nextMonth.year, nextMonth.month,
      math.min(now.day, DateTime(nextMonth.year, nextMonth.month + 1, 0).day));
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
        title: const Text('Kredit əlavə et'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Kreditin adı')),
          TextField(controller: principal, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Əsas borc (AZN)')),
          TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'İllik nominal faiz (%)')),
          TextField(controller: months, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Müddət (ay)')),
          const SizedBox(height: 8),
          TextButton.icon(icon: const Icon(Icons.calendar_month),
            label: Text('İlk ödəniş: ${firstDue.day}.${firstDue.month}.${firstDue.year}'),
            onPressed: () async {
              final picked = await showDatePicker(context: dialogContext,
                initialDate: firstDue, firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (picked != null) refresh(() => firstDue = picked);
            }),
          const Text('Təxmini cədvəl: komissiya, sığorta və bankın gündəlik faiz qaydası daxil deyil.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
          FilledButton(onPressed: () async {
            try {
              if (name.text.trim().isEmpty) throw const FormatException();
              final yearlyBps = Money.parseAzN(rate.text);
              final count = int.parse(months.text.trim());
              final now = DateTime.now();
              final loan = Loan(id: '${now.microsecondsSinceEpoch}', name: name.text.trim(),
                principalQepik: Money.parseAzN(principal.text), annualRateBps: yearlyBps,
                months: count, firstDueDate: firstDue);
              LoanSchedule.generate(loan);
              await widget.ledger.addLoan(loan);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _load();
            } catch (_) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Ad, məbləğ, faiz və müddəti düzgün daxil edin.')));
            }
          }, child: const Text('Yadda saxla')),
        ],
      )));
    } finally { name.dispose(); principal.dispose(); rate.dispose(); months.dispose(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kreditlər')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _add,
        icon: const Icon(Icons.add), label: const Text('Kredit')),
    body: error != null ? Center(child: Text(error!)) : loans.isEmpty
        ? const Center(child: Text('Hələ kredit əlavə edilməyib.'))
        : ListView(padding: const EdgeInsets.all(16), children: [
          for (final loan in loans) _loanCard(loan),
          const SizedBox(height: 80),
        ]),
  );

  Widget _loanCard(Loan loan) {
    final schedule = LoanSchedule.generate(loan);
    return Card(child: ExpansionTile(
      title: Text(loan.name),
      subtitle: Text('${Money.format(loan.principalQepik)} · ${loan.annualRateBps / 100}% · ${loan.months} ay'),
      children: [
        ListTile(title: const Text('Təxmini nominal faiz cəmi'),
          trailing: Text(Money.format(LoanSchedule.totalInterest(schedule)))),
        for (final item in schedule) ListTile(
          dense: true,
          title: Text('${item.number}. ${item.dueDate.day}.${item.dueDate.month}.${item.dueDate.year}'),
          subtitle: Text('Faiz ${Money.format(item.interestQepik)} · Qalıq ${Money.format(item.balanceQepik)}'),
          trailing: Text(Money.format(item.paymentQepik)),
        ),
      ],
    ));
  }
}

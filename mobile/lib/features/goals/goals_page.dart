import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../transactions/local_ledger.dart';
import 'goal.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.ledger});
  final LocalLedger ledger;
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<SavingsGoal> goals = [];
  Map<String, int> balances = {};
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final result = await widget.ledger.goals();
      final totals = <String, int>{};
      for (final goal in result) { totals[goal.id] = await widget.ledger.goalBalance(goal.id); }
      if (mounted) setState(() { goals = result; balances = totals; error = null; });
    } catch (_) { if (mounted) setState(() => error = 'Məqsədlər açıla bilmədi.'); }
  }
  Future<void> _addGoal() async {
    final name = TextEditingController();
    final target = TextEditingController();
    var deadline = DateTime(DateTime.now().year, DateTime.now().month + 6);
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Yığım məqsədi'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Məqsədin adı')),
            TextField(controller: target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hədəf (AZN)')),
            TextButton.icon(icon: const Icon(Icons.calendar_month),
              label: Text('Son tarix: ${deadline.day}.${deadline.month}.${deadline.year}'),
              onPressed: () async {
                final picked = await showDatePicker(context: dialogContext,
                  initialDate: deadline, firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)));
                if (picked != null) refresh(() => deadline = picked);
              }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
            FilledButton(onPressed: () async {
              try {
                final value = Money.parseAzN(target.text);
                if (name.text.trim().isEmpty || value <= 0) throw const FormatException();
                await widget.ledger.addGoal(SavingsGoal(
                  id: '${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(),
                  targetQepik: value, deadline: deadline));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Ad və müsbət hədəf məbləği daxil edin.')));
              }
            }, child: const Text('Yadda saxla')),
          ],
        ),
      ));
    } finally { name.dispose(); target.dispose(); }
  }
  Future<void> _editGoal(SavingsGoal goal) async {
    final name = TextEditingController(text: goal.name);
    final target = TextEditingController(text: (goal.targetQepik / 100).toStringAsFixed(2));
    var deadline = goal.deadline;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Məqsədi düzəlt'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Məqsədin adı')),
            TextField(controller: target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hədəf (AZN)')),
            TextButton.icon(icon: const Icon(Icons.calendar_month),
              label: Text('Son tarix: ${deadline.day}.${deadline.month}.${deadline.year}'),
              onPressed: () async {
                final today = DateTime.now();
                final picked = await showDatePicker(context: dialogContext,
                  initialDate: deadline.isBefore(today) ? today : deadline,
                  firstDate: today, lastDate: today.add(const Duration(days: 3650)));
                if (picked != null) refresh(() => deadline = picked);
              }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
            FilledButton(onPressed: () async {
              try {
                final value = Money.parseAzN(target.text);
                if (name.text.trim().isEmpty || value <= 0) throw const FormatException();
                await widget.ledger.updateGoal(SavingsGoal(id: goal.id,
                  name: name.text.trim(), targetQepik: value, deadline: deadline));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Məqsəd yadda saxlanmadı.')));
              }
            }, child: const Text('Yadda saxla')),
          ],
        ),
      ));
    } finally { name.dispose(); target.dispose(); }
  }

  Future<void> _move(SavingsGoal goal, {required bool withdraw}) async {
    final amount = TextEditingController();
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(withdraw ? 'Yığımdan götür' : 'Yığıma əlavə et'),
        content: TextField(controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
          FilledButton(onPressed: () async {
            try {
              final value = Money.parseAzN(amount.text);
              if (value <= 0) throw const FormatException();
              final now = DateTime.now();
              await widget.ledger.moveGoalMoney(GoalMovement(
                id: '${now.microsecondsSinceEpoch}', goalId: goal.id,
                deltaQepik: withdraw ? -value : value, createdAt: now));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _load();
            } catch (_) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Məbləği yoxlayın. Ayrılan puldan artıq götürmək olmaz.')));
            }
          }, child: const Text('Qeyd et')),
        ],
      ));
    } finally { amount.dispose(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Məqsədlər')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addGoal,
      icon: const Icon(Icons.add), label: const Text('Məqsəd')),
    body: error != null ? Center(child: Text(error!)) : ListView(
      padding: const EdgeInsets.all(16), children: [
        const Text('Buradakı yığım qeydləri banka pul köçürmür və aylıq xərc sayılmır.'),
        if (goals.isEmpty) const Padding(padding: EdgeInsets.all(20),
          child: Text('Hələ yığım məqsədi yoxdur.')),
        for (final goal in goals) _goalCard(goal),
        const SizedBox(height: 80),
      ]),
  );
  Widget _goalCard(SavingsGoal goal) {
    final progress = GoalProgress(goal, balances[goal.id] ?? 0);
    final monthly = progress.monthlyNeededQepik(DateTime.now());
    return Card(child: ExpansionTile(title: Text(goal.name),
      subtitle: Text('${Money.format(progress.savedQepik)} / ${Money.format(goal.targetQepik)}'),
      children: [Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 8),
          Text('Qalıb: ${Money.format(progress.remainingQepik)}'),
          Text('Son tarix: ${goal.deadline.day}.${goal.deadline.month}.${goal.deadline.year}'),
          Text(monthly == null ? 'Son tarix keçib.' : monthly == 0
            ? 'Məqsədə çatılıb.' : 'Bu aydan başlayaraq təxmini: ${Money.format(monthly)}/ay'),
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed: () => _editGoal(goal),
              icon: const Icon(Icons.edit), label: const Text('Düzəlt')),
            FilledButton(onPressed: () => _move(goal, withdraw: false), child: const Text('Əlavə et')),
            OutlinedButton(onPressed: progress.savedQepik == 0 ? null :
              () => _move(goal, withdraw: true), child: const Text('Götür')),
          ]),
          FutureBuilder<List<GoalMovement>>(future: widget.ledger.goalMovements(goal.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Tarixçə açıla bilmədi.');
              if (!snapshot.hasData) return const Text('Tarixçə yüklənir…');
              return Column(children: [for (final move in snapshot.data!) ListTile(
                dense: true, title: Text('${move.createdAt.day}.${move.createdAt.month}.${move.createdAt.year}'),
                trailing: Text('${move.deltaQepik > 0 ? '+' : ''}${Money.format(move.deltaQepik)}'),
              )]);
            }),
        ]))],
    ));
  }
}

import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../transactions/local_ledger.dart';
import '../transactions/transaction.dart';
import 'expense_report.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.ledger, required this.entries,
    required this.onAddExpense, required this.onRefresh});
  final LocalLedger ledger;
  final List<LedgerEntry> entries;
  final VoidCallback onAddExpense;
  final Future<void> Function() onRefresh;
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? category;
  String query = '';
  Map<String, int> budgets = {};
  String? error;
  @override
  void initState() { super.initState(); _loadBudgets(); }
  Future<void> _loadBudgets() async {
    final requestedMonth = month;
    try {
      final result = await widget.ledger.budgets(requestedMonth);
      if (mounted && month == requestedMonth) setState(() { budgets = result; error = null; });
    } catch (_) { if (mounted && month == requestedMonth) setState(() => error = 'Limitlər açıla bilmədi.'); }
  }
  void _changeMonth(int delta) {
    setState(() { month = DateTime(month.year, month.month + delta); category = null; budgets = {}; });
    _loadBudgets();
  }
  Future<void> _editBudget(String selected) async {
    final controller = TextEditingController(
      text: budgets[selected] == null ? '' : (budgets[selected]! / 100).toStringAsFixed(2));
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('$selected limiti'),
        content: TextField(controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Aylıq limit (AZN)')),
        actions: [
          if (budgets[selected] != null) TextButton(onPressed: () async {
            await widget.ledger.removeBudget(month, selected);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            await _loadBudgets();
          }, child: const Text('Limiti sil')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
          FilledButton(onPressed: () async {
            try {
              final value = Money.parseAzN(controller.text);
              if (value <= 0) throw const FormatException();
              await widget.ledger.setBudget(month, selected, value);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _loadBudgets();
            } catch (_) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Müsbət limit daxil edin.')));
            }
          }, child: const Text('Yadda saxla')),
        ],
      ));
    } finally { controller.dispose(); }
  }
  Future<void> _editExpense(LedgerEntry entry) async {
    final amount = TextEditingController(text: (entry.amountQepik / 100).toStringAsFixed(2));
    final note = TextEditingController(text: entry.note);
    var category = entry.category;
    var date = entry.occurredAt;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Xərci düzəlt'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
            DropdownButtonFormField<String>(initialValue: category,
              items: {...expenseCategories, category}.map((item) =>
                DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) { if (value != null) refresh(() => category = value); }),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Qeyd')),
            TextButton.icon(icon: const Icon(Icons.calendar_month),
              label: Text('${date.day}.${date.month}.${date.year}'),
              onPressed: () async {
                final picked = await showDatePicker(context: dialogContext,
                  initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (picked != null) refresh(() => date = picked);
              }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
            FilledButton(onPressed: () async {
              try {
                final value = Money.parseAzN(amount.text);
                if (value <= 0) throw const FormatException();
                await widget.ledger.updateExpense(LedgerEntry(id: entry.id,
                  kind: EntryKind.expense, amountQepik: value, category: category,
                  note: note.text.trim(), occurredAt: date));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await widget.onRefresh();
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Xərc yadda saxlanmadı. Məbləği yoxlayın.')));
              }
            }, child: const Text('Yadda saxla')),
          ],
        ),
      ));
    } finally { amount.dispose(); note.dispose(); }
  }

  Future<void> _deleteExpense(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Xərci silinsin?'),
      content: Text('${entry.category} · ${Money.format(entry.amountQepik)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    ));
    if (confirmed != true) return;
    try {
      await widget.ledger.deleteExpense(entry.id);
      await widget.onRefresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xərc silinə bilmədi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ExpenseReport(widget.entries, month);
    final totals = report.byCategory;
    final categories = {...expenseCategories, ...totals.keys}.toList();
    final filtered = report.filtered(category: category, query: query);
    return Scaffold(
      appBar: AppBar(title: const Text('Xərclər')),
      floatingActionButton: FloatingActionButton.extended(onPressed: widget.onAddExpense,
        icon: const Icon(Icons.add), label: const Text('Xərc əlavə et')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
          Text('${month.month.toString().padLeft(2, '0')}.${month.year}',
            style: Theme.of(context).textTheme.titleLarge),
          IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
        ]),
        Card(child: Padding(padding: const EdgeInsets.all(18),
          child: Text('Ayın xərci: ${Money.format(report.totalQepik)}',
            style: Theme.of(context).textTheme.titleLarge))),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        Text('Kateqoriyalar və limitlər', style: Theme.of(context).textTheme.titleMedium),
        for (final item in categories) if ((totals[item] ?? 0) > 0 || budgets[item] != null)
          _categoryCard(item, totals[item] ?? 0),
        if (totals.isEmpty && budgets.isEmpty) const Padding(padding: EdgeInsets.all(12),
          child: Text('Bu ay xərc və limit yoxdur.')),
        TextButton.icon(onPressed: () async {
          final selected = await showDialog<String>(context: context, builder: (context) =>
            SimpleDialog(title: const Text('Limit kateqoriyası'), children: [
              for (final item in categories) SimpleDialogOption(onPressed: () => Navigator.pop(context, item),
                child: Text(item)),
            ]));
          if (selected != null) await _editBudget(selected);
        }, icon: const Icon(Icons.tune), label: const Text('Aylıq limit təyin et')),
        const Divider(height: 32),
        TextField(onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            labelText: 'Kateqoriya və ya qeyddə axtar')),
        DropdownButtonFormField<String>(initialValue: category,
          decoration: const InputDecoration(labelText: 'Kateqoriya filtri'),
          items: [const DropdownMenuItem<String>(value: null, child: Text('Hamısı')),
            for (final item in categories) DropdownMenuItem(value: item, child: Text(item))],
          onChanged: (value) => setState(() => category = value)),
        const SizedBox(height: 8),
        Text('Əməliyyatlar (${filtered.length})', style: Theme.of(context).textTheme.titleMedium),
        if (filtered.isEmpty) const ListTile(title: Text('Uyğun xərc tapılmadı.')),
        for (final item in filtered) ListTile(
          title: Text(item.category),
          subtitle: Text('${item.occurredAt.day}.${item.occurredAt.month}.${item.occurredAt.year}'
              '${item.note.isEmpty ? '' : ' · ${item.note}'}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(Money.format(item.amountQepik)),
            if (!item.id.startsWith('loan_')) PopupMenuButton<String>(
              tooltip: 'Xərc əməliyyatları',
              onSelected: (action) {
                if (action == 'edit') _editExpense(item);
                if (action == 'delete') _deleteExpense(item);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzəlt')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ]),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
  Widget _categoryCard(String name, int spent) {
    final limit = budgets[name];
    return Card(child: InkWell(onTap: () => _editBudget(name),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name)), Text(Money.format(spent))]),
          if (limit != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (spent / limit).clamp(0.0, 1.0),
              color: spent > limit ? Theme.of(context).colorScheme.error : null),
            Text(spent > limit
              ? 'Limit ${Money.format(spent - limit)} aşılıb · ${Money.format(limit)}'
              : 'Qalıq ${Money.format(limit - spent)} · limit ${Money.format(limit)}'),
          ],
        ]))));
  }
}

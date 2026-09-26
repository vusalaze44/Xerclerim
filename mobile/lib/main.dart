import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'core/money.dart';
import 'features/dashboard/home_dashboard.dart';
import 'features/transactions/local_ledger.dart';
import 'features/transactions/transaction.dart';
import 'features/loans/loans_page.dart';
import 'features/expenses/expenses_page.dart';
import 'features/expenses/expense_report.dart';
import 'features/planning/planning_page.dart';
import 'features/goals/goals_page.dart';
import 'features/backup/backup_page.dart';
import 'features/backup/account_entry.dart';
import 'features/debts/debts_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    firebaseReady = true;
  }
  catch (_) { /* The local app remains usable before Firebase is configured. */ }
  runApp(XerclerimApp(firebaseReady: firebaseReady));
}

class XerclerimApp extends StatelessWidget {
  const XerclerimApp({super.key, required this.firebaseReady});
  final bool firebaseReady;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Xərclərim', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: dashboardPurple,
      scaffoldBackgroundColor: const Color(0xfff7f8fc),
      useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: dashboardPurple,
      brightness: Brightness.dark, useMaterial3: true),
    home: firebaseReady ? StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final uid = snapshot.data?.uid;
        return LedgerPage(key: ValueKey(uid ?? 'guest'),
          ownerUid: uid, firebaseReady: true);
      },
    ) : const LedgerPage(ownerUid: null, firebaseReady: false),
  );
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.ownerUid, required this.firebaseReady});
  final String? ownerUid;
  final bool firebaseReady;
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late final LocalLedger ledger;
  List<LedgerEntry> entries = [];
  String? error;
  int selectedTab = 0;
  @override
  void initState() { super.initState(); ledger = LocalLedger(ownerUid: widget.ownerUid); _load(); }
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
    var occurredAt = DateTime.now();
    final categories = kind == EntryKind.income
        ? ['Əməkhaqqı', 'Əlavə gəlir', 'Digər']
        : expenseCategories;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(kind == EntryKind.income ? 'Gəlir əlavə et' : 'Xərc əlavə et'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Məbləğ (AZN)')),
            DropdownButtonFormField<String>(initialValue: category, items: categories.map((item) =>
              DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) { if (value != null) refresh(() => category = value); }),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Qeyd (istəyə bağlı)')),
            TextButton.icon(icon: const Icon(Icons.calendar_month),
              label: Text('Tarix: ${occurredAt.day}.${occurredAt.month}.${occurredAt.year}'),
              onPressed: () async {
                final picked = await showDatePicker(context: dialogContext,
                  initialDate: occurredAt, firstDate: DateTime(2000),
                  lastDate: DateTime.now());
                if (picked != null) refresh(() => occurredAt = picked);
              }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ləğv et')),
            FilledButton(onPressed: () async {
              try {
                final qepik = Money.parseAzN(amount.text);
                if (qepik <= 0) throw const FormatException();
                await ledger.add(LedgerEntry(id: '${DateTime.now().microsecondsSinceEpoch}', kind: kind,
                  amountQepik: qepik, category: category, note: note.text.trim(), occurredAt: occurredAt));
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

  void _selectTab(int value) {
    setState(() => selectedTab = value);
    _load();
  }

  void _openBackup() => Navigator.push(context, MaterialPageRoute<void>(
    builder: (context) => BackupPage(ledger: ledger, ownerUid: widget.ownerUid,
      firebaseReady: widget.firebaseReady, onRefresh: _load,
      email: widget.firebaseReady ? FirebaseAuth.instance.currentUser?.email : null)));

  Future<void> _openDebts() async {
    if (!widget.firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dost sorğusu üçün Firebase və App Check quraşdırılmalıdır.')));
      return;
    }
    var uid = widget.ownerUid;
    if (uid == null) {
      final signIn = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Dost sorğusu üçün giriş'),
        content: const Text('Xərc, gəlir və digər lokal əməliyyatlara girişsiz davam edə bilərsiniz. Dost sorğusunu qarşılıqlı təsdiqləmək üçün Google hesabı tələb olunur.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Sonra')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Google ilə daxil ol'))],
      ));
      if (signIn != true || !mounted) return;
      try { uid = (await signInWithGuestContinuity(context, ledger))?.uid; }
      catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google girişi tamamlanmadı.')));
        return;
      }
    }
    if (uid != null && mounted) Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DebtsPage(uid: uid!)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7f8fc),
    bottomNavigationBar: _bottomNavigation(),
    body: selectedTab == 4 ? GoalsPage(ledger: ledger) :
      selectedTab == 3 ? PlanningPage(entries: entries) :
      selectedTab == 2 ? LoansPage(ledger: ledger) :
      selectedTab == 1 ? ExpensesPage(ledger: ledger, entries: entries,
        onAddExpense: () => _add(EntryKind.expense), onRefresh: _load) :
      error != null ? Center(child: Text(error!)) : HomeDashboard(
        entries: entries,
        name: widget.firebaseReady ? FirebaseAuth.instance.currentUser?.displayName : null,
        onBackup: _openBackup,
        onIncome: () => _add(EntryKind.income),
        onExpense: () => _selectTab(1),
        onLoans: () => _selectTab(2),
        onBudget: () => _selectTab(1),
        onGoals: () => _selectTab(4),
        onPlan: () => _selectTab(3),
        onDebts: _openDebts,
      ),
  );

  Widget _bottomNavigation() => SafeArea(top: false, child: Container(
    height: 72, margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: const Color(0xffebe6fb),
      borderRadius: BorderRadius.circular(42)),
    child: Row(children: [
      _navItem(0, Icons.home_outlined, 'Ana'),
      _navItem(1, Icons.receipt_long_outlined, 'Xərc'),
      _navItem(2, Icons.account_balance_outlined, 'Kredit'),
      _navItem(3, Icons.calendar_month_outlined, 'Plan'),
      _navItem(4, Icons.favorite_border_rounded, 'Məqsəd'),
    ]),
  ));

  Widget _navItem(int index, IconData icon, String label) {
    final selected = selectedTab == index;
    return Expanded(flex: selected ? 3 : 1, child: InkWell(
      onTap: () => _selectTab(index), borderRadius: BorderRadius.circular(35),
      child: Container(
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(35)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: selected ? dashboardPurple : Colors.transparent,
              shape: BoxShape.circle),
            child: Icon(icon, color: selected ? Colors.white : dashboardPurple, size: 24)),
          if (selected) ...[
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xff654db2),
                fontSize: 13, fontWeight: FontWeight.w700))),
          ],
        ]),
      ),
    ));
  }
}

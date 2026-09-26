import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../transactions/transaction.dart';
import 'summary.dart';

const dashboardPurple = Color(0xff7455ee);
const dashboardInk = Color(0xff252538);

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key, required this.entries, required this.name,
    required this.onBackup, required this.onIncome, required this.onExpense,
    required this.onLoans, required this.onBudget, required this.onGoals,
    required this.onPlan, required this.onDebts});
  final List<LedgerEntry> entries;
  final String? name;
  final VoidCallback onBackup;
  final VoidCallback onIncome;
  final VoidCallback onExpense;
  final VoidCallback onLoans;
  final VoidCallback onBudget;
  final VoidCallback onGoals;
  final VoidCallback onPlan;
  final VoidCallback onDebts;
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  DateTime selectedDate = DateTime.now();
  static const weekdays = ['B.e.', 'Ç.a.', 'Ç.', 'C.a.', 'C.', 'Ş.', 'B.'];
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = MonthlySummary.from(widget.entries, now);
    final greeting = widget.name?.trim().split(' ').first;
    final dayEntries = widget.entries.where((entry) =>
      entry.occurredAt.year == selectedDate.year &&
      entry.occurredAt.month == selectedDate.month &&
      entry.occurredAt.day == selectedDate.day).toList();
    return ColoredBox(color: const Color(0xfff7f8fc), child: SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 22), children: [
        Row(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: dashboardPurple, size: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Salam, ${greeting == null || greeting.isEmpty ? 'dostum' : greeting} 👋',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dashboardInk)),
            const Text('Pulunu rahat idarə et', style: TextStyle(fontSize: 13, color: Color(0xff777888))),
          ])),
          _headerAction(Icons.cloud_outlined, widget.onBackup, light: true, tooltip: 'Google yedəyi'),
          const SizedBox(width: 8),
          _headerAction(Icons.person_outline_rounded, widget.onBackup, light: false, tooltip: 'Hesab'),
        ]),
        const SizedBox(height: 18),
        _hero(summary),
        const SizedBox(height: 18),
        SizedBox(height: 58, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: 9,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final date = DateTime(now.year, now.month, now.day + index - 4);
            final selected = date.year == selectedDate.year &&
              date.month == selectedDate.month && date.day == selectedDate.day;
            return InkWell(onTap: () => setState(() => selectedDate = date),
              borderRadius: BorderRadius.circular(22),
              child: Container(width: 55, padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? dashboardPurple : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: selected ? null : Border.all(color: const Color(0xffe9e9f0))),
                child: Column(children: [
                  Text(weekdays[date.weekday - 1], style: TextStyle(fontSize: 12,
                    color: selected ? Colors.white70 : const Color(0xff777888))),
                  Text('${date.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : dashboardInk)),
                ])));
          },
        )),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 330 ? 2 : 3;
          final cardWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10,
            childAspectRatio: cardWidth / (columns == 3 ? 158 : 166),
            children: [
              _tile('Xərclər', 'Gündəlik hesabat', '💸', const Color(0xffe2f5e8), widget.onExpense),
              _tile('Gəlirlər', 'Maaş və əlavələr', '💰', const Color(0xffe7ecff), widget.onIncome),
              _tile('Kreditlər', 'Ödəniş cədvəli', '🏦', const Color(0xfffff5d9), widget.onLoans),
              _tile('Büdcə', 'Kateqoriya limiti', '📊', const Color(0xffdef5f4), widget.onBudget),
              _tile('Məqsədlər', 'Yığım planı', '🎯', const Color(0xffffeada), widget.onGoals),
              _tile('Dost borcu', 'Sorğu və qaytarma', '🤝', const Color(0xffffe5ee), widget.onDebts),
            ],
          );
        }),
        const SizedBox(height: 18),
        InkWell(onTap: widget.onPlan, borderRadius: BorderRadius.circular(28), child: Container(
          height: 104, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(colors: [Color(0xff39268d), Color(0xff8965ed)])),
          child: Row(children: [
            const Text('✨', style: TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Alım, yoxsa almayım?', style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Gələcək pul axınını müqayisə et',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ]))),
        const SizedBox(height: 18),
        Text('${selectedDate.day}.${selectedDate.month} əməliyyatları',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: dashboardInk)),
        if (dayEntries.isEmpty) const Padding(padding: EdgeInsets.all(14),
          child: Text('Bu tarixdə qeyd yoxdur.', style: TextStyle(color: Color(0xff777888)))),
        for (final entry in dayEntries.take(4)) ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CircleAvatar(backgroundColor: const Color(0xffefebff),
            child: Icon(entry.kind == EntryKind.income ? Icons.south_west : Icons.north_east,
              color: dashboardPurple)),
          title: Text(entry.category),
          subtitle: entry.note.isEmpty ? null : Text(entry.note, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text('${entry.kind == EntryKind.income ? '+' : '-'}${Money.format(entry.amountQepik)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    ));
  }

  Widget _headerAction(IconData icon, VoidCallback onTap, {required bool light, required String tooltip}) =>
    Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(width: 48, height: 52,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
          color: light ? const Color(0xffede8ff) : dashboardPurple),
        child: Icon(icon, color: light ? const Color(0xff6b61a5) : Colors.white))));

  Widget _hero(MonthlySummary summary) => Container(
    height: 185, padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
      boxShadow: const [BoxShadow(color: Color(0x307556ee), blurRadius: 16, offset: Offset(0, 7))],
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xff8063f7), Color(0xff4e35ad), Color(0xff282070)])),
    child: Stack(children: [
      Positioned(right: -20, top: -65, child: Container(width: 175, height: 175,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: const Color(0x35ffffff), width: 26)))),
      Positioned(right: 15, bottom: -34, child: Icon(Icons.auto_graph_rounded,
        size: 120, color: Colors.white.withValues(alpha: 0.12))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BU AYIN PUL AXINI', style: TextStyle(color: Colors.white70, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 1.1)),
        const SizedBox(height: 6),
        Text(Money.format(summary.balanceQepik), style: const TextStyle(color: Colors.white,
          fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Qeyd olunan gəlir − xərc', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Wrap(spacing: 9, runSpacing: 6, children: [
          _heroChip('↑ ${Money.format(summary.incomeQepik)}'),
          _heroChip('↓ ${Money.format(summary.expenseQepik)}'),
        ]),
      ]),
    ]),
  );

  Widget _heroChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: const Color(0x30ffffff), borderRadius: BorderRadius.circular(18)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11,
      fontWeight: FontWeight.w600)));

  Widget _tile(String title, String subtitle, String emoji, Color color, VoidCallback onTap) =>
    Material(color: color, borderRadius: BorderRadius.circular(28),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(28),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: Container(width: 57, height: 57,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45),
                shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 36))))),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: dashboardInk, fontSize: 16,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xff797b89), fontSize: 11, height: 1.2)),
          ]))));
}

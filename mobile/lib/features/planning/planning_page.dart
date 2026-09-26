import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../dashboard/summary.dart';
import '../transactions/transaction.dart';
import 'scenario.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key, required this.entries});
  final List<LedgerEntry> entries;
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final futureIncome = TextEditingController();
  final futureExpenses = TextEditingController();
  final price = TextEditingController();
  final deposit = TextEditingController();
  final monthly = TextEditingController();
  final months = TextEditingController();
  bool installment = false;
  String? error;
  PurchaseScenario? result;

  @override
  void dispose() {
    for (final controller in [futureIncome, futureExpenses, price, deposit, monthly, months]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _amount(TextEditingController controller) =>
      controller.text.trim().isEmpty ? 0 : Money.parseAzN(controller.text);

  void _calculate() {
    try {
      final scenario = PurchaseScenario(
        currentMonth: MonthlySummary.from(widget.entries, DateTime.now()),
        futureIncomeQepik: _amount(futureIncome),
        futureExpensesQepik: _amount(futureExpenses),
        priceQepik: _amount(price),
        depositQepik: installment ? _amount(deposit) : 0,
        monthlyPaymentQepik: installment ? _amount(monthly) : 0,
        installmentMonths: installment ? int.parse(months.text.trim()) : 0,
      );
      scenario.validate();
      setState(() { result = scenario; error = null; });
    } catch (_) {
      setState(() { result = null; error = 'Məbləğləri yoxlayın. Hissəli alışda ümumi ödəniş qiymətdən az olmamalıdır.'; });
    }
  }

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller,
      onChanged: (_) => setState(() { result = null; error = null; }),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  @override
  Widget build(BuildContext context) {
    final summary = MonthlySummary.from(widget.entries, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Ay sonu planı')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Bu ay qeydə alınan gəlir − xərc: ${Money.format(summary.balanceQepik)}',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Bu rəqəm bank hesabınızın balansı deyil. Yalnız tətbiqə yazdığınız əməliyyatlara əsaslanır.'),
        const SizedBox(height: 16),
        _field('Ayın qalan hissəsində gözlənən gəlir (AZN)', futureIncome),
        _field('Ayın qalan hissəsində gözlənən xərc (AZN)', futureExpenses),
        const SizedBox(height: 10),
        Text('Alım, yoxsa almayım?', style: Theme.of(context).textTheme.titleLarge),
        _field('Alışın nağd qiyməti (AZN)', price),
        SwitchListTile(title: const Text('Hissəli ödəniş ssenarisi'),
          value: installment, onChanged: (value) => setState(() { installment = value; result = null; })),
        if (installment) ...[
          const Text('İlk aylıq ödənişin bu ay ediləcəyini fərz edirik.'),
          _field('İlkin ödəniş (AZN)', deposit),
          _field('Aylıq ödəniş (AZN)', monthly),
          Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: months,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() { result = null; error = null; }),
            decoration: const InputDecoration(labelText: 'Ay sayı', border: OutlineInputBorder()))),
        ],
        FilledButton(onPressed: _calculate, child: const Text('Ssenarini hesabla')),
        if (error != null) Padding(padding: const EdgeInsets.all(8),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (result != null) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alışsız ay sonu fərqi: ${Money.format(result!.baselineQepik)}'),
              Text('Nağd alışdan sonra: ${Money.format(result!.cashAfterQepik)}'),
              if (installment) ...[
                Text('Hissəli alışın bu ayından sonra: ${Money.format(result!.installmentAfterThisMonthQepik)}'),
                Text('Bütün hissəli ödənişlər: ${Money.format(result!.installmentTotalQepik)}'),
                Text('Nağd qiymətdən fərq: ${Money.format(result!.financingDifferenceQepik)}'),
              ],
            ],
          ))),
          const Text('Nəticə yalnız daxil etdiyiniz məbləğlərə əsaslanır. Sonrakı aylardakı gəlir, digər borclar, komissiya və gözlənilməz xərclər avtomatik hesablanmır.'),
        ],
      ]),
    );
  }
}

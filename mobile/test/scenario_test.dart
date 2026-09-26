import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/features/dashboard/summary.dart';
import 'package:xerclerim/features/planning/scenario.dart';

void main() {
  test('alışsız, nağd və hissəli bu ay fərqini ayrı hesablayır', () {
    const scenario = PurchaseScenario(currentMonth: MonthlySummary(120000, 55000),
      futureIncomeQepik: 10000, futureExpensesQepik: 20000,
      priceQepik: 30000, depositQepik: 5000,
      monthlyPaymentQepik: 3000, installmentMonths: 10);
    expect(scenario.baselineQepik, 55000);
    expect(scenario.cashAfterQepik, 25000);
    expect(scenario.installmentAfterThisMonthQepik, 47000);
    expect(scenario.installmentTotalQepik, 35000);
    expect(scenario.financingDifferenceQepik, 5000);
  });
  test('çatışmayan hissəli ödəniş ssenarisini rədd edir', () {
    const scenario = PurchaseScenario(currentMonth: MonthlySummary(0, 0),
      futureIncomeQepik: 0, futureExpensesQepik: 0,
      priceQepik: 30000, depositQepik: 0,
      monthlyPaymentQepik: 1000, installmentMonths: 12);
    expect(scenario.validate, throwsFormatException);
  });
}

import '../dashboard/summary.dart';

/// Cash-flow estimate for the current month. It is not an account balance.
class PurchaseScenario {
  const PurchaseScenario({required this.currentMonth, required this.futureIncomeQepik,
    required this.futureExpensesQepik, required this.priceQepik,
    required this.depositQepik, required this.monthlyPaymentQepik,
    required this.installmentMonths});

  final MonthlySummary currentMonth;
  final int futureIncomeQepik;
  final int futureExpensesQepik;
  final int priceQepik;
  final int depositQepik;
  final int monthlyPaymentQepik;
  final int installmentMonths;

  void validate() {
    if (futureIncomeQepik < 0 || futureExpensesQepik < 0 || priceQepik < 0 ||
        depositQepik < 0 || monthlyPaymentQepik < 0 || installmentMonths < 0 ||
        installmentMonths > 600 || depositQepik > priceQepik ||
        (installmentMonths == 0 && (depositQepik != 0 || monthlyPaymentQepik != 0)) ||
        (installmentMonths > 0 && (monthlyPaymentQepik == 0 ||
          depositQepik + monthlyPaymentQepik * installmentMonths < priceQepik))) {
      throw const FormatException('Ssenari məbləğləri uyğun deyil.');
    }
  }

  int get baselineQepik {
    validate();
    return currentMonth.balanceQepik + futureIncomeQepik - futureExpensesQepik;
  }

  int get cashAfterQepik => baselineQepik - priceQepik;
  int get installmentAfterThisMonthQepik =>
      baselineQepik - depositQepik - monthlyPaymentQepik;
  int get installmentTotalQepik => depositQepik + monthlyPaymentQepik * installmentMonths;
  int get financingDifferenceQepik => installmentTotalQepik - priceQepik;
}

import 'dart:math' as math;

/// Rate is annual nominal basis points (100 bps = 1%).
class Loan {
  const Loan({required this.id, required this.name, required this.principalQepik,
    required this.annualRateBps, required this.months, required this.firstDueDate});
  final String id;
  final String name;
  final int principalQepik;
  final int annualRateBps;
  final int months;
  final DateTime firstDueDate;
}

class LoanInstallment {
  const LoanInstallment(this.number, this.dueDate, this.paymentQepik,
    this.interestQepik, this.principalQepik, this.balanceQepik);
  final int number;
  final DateTime dueDate;
  final int paymentQepik;
  final int interestQepik;
  final int principalQepik;
  final int balanceQepik;
}

class LoanSchedule {
  static List<LoanInstallment> generate(Loan loan) {
    if (loan.principalQepik <= 0 || loan.months < 1 || loan.months > 600 ||
        loan.months > loan.principalQepik ||
        loan.annualRateBps < 0 || loan.annualRateBps > 100000) {
      throw const FormatException('Kredit şərtləri düzgün deyil.');
    }
    final monthlyRate = loan.annualRateBps / 120000;
    final payment = monthlyRate == 0
        ? (loan.principalQepik / loan.months).ceil()
        : (loan.principalQepik * monthlyRate /
            (1 - math.pow(1 + monthlyRate, -loan.months))).round();
    var balance = loan.principalQepik;
    final result = <LoanInstallment>[];
    for (var i = 0; i < loan.months; i++) {
      final interest = (balance * loan.annualRateBps / 120000).round();
      final principal = i == loan.months - 1
          ? balance
          : math.min(balance, math.max(1, payment - interest));
      balance -= principal;
      final year = loan.firstDueDate.year + (loan.firstDueDate.month - 1 + i) ~/ 12;
      final month = (loan.firstDueDate.month - 1 + i) % 12 + 1;
      final lastDay = DateTime(year, month + 1, 0).day;
      final due = DateTime(year, month,
          math.min(loan.firstDueDate.day, lastDay));
      result.add(LoanInstallment(i + 1, due, principal + interest,
          interest, principal, balance));
    }
    return result;
  }

  static int totalInterest(List<LoanInstallment> schedule) =>
      schedule.fold(0, (total, item) => total + item.interestQepik);
}

/// A manually recorded cash payment; it does not recalculate bank interest.
class LoanPayment {
  const LoanPayment({required this.id, required this.loanId,
    required this.amountQepik, required this.paidAt});
  final String id;
  final String loanId;
  final int amountQepik;
  final DateTime paidAt;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/features/loans/loan.dart';

void main() {
  test('faizsiz kreditin son qəpiyi də ödənir', () {
    final schedule = LoanSchedule.generate(Loan(id: 'a', name: 'Test',
      principalQepik: 10000, annualRateBps: 0, months: 3,
      firstDueDate: DateTime(2026, 1, 31)));
    expect(schedule.map((item) => item.paymentQepik).toList(), [3334, 3334, 3332]);
    expect(schedule.last.balanceQepik, 0);
    expect(schedule[1].dueDate.day, 28);
    expect(LoanSchedule.totalInterest(schedule), 0);
  });
  test('faiz yükü hesablanır və son qalıq sıfırlanır', () {
    final schedule = LoanSchedule.generate(Loan(id: 'b', name: 'Test',
      principalQepik: 120000, annualRateBps: 1200, months: 12,
      firstDueDate: DateTime(2026, 10, 15)));
    expect(schedule.first.interestQepik, 1200);
    expect(schedule.last.balanceQepik, 0);
    expect(schedule.fold<int>(0, (total, item) => total + item.principalQepik), 120000);
  });
}

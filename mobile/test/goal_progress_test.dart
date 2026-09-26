import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/features/goals/goal.dart';

void main() {
  test('qalan yığım və aylıq məbləğ qəpik dəqiqliyi ilə hesablanır', () {
    final goal = SavingsGoal(id: 'x', name: 'Ehtiyat fondu',
      targetQepik: 10001, deadline: DateTime(2026, 12, 31));
    final progress = GoalProgress(goal, 2000);
    expect(progress.remainingQepik, 8001);
    expect(progress.monthlyNeededQepik(DateTime(2026, 9, 26)), 2001);
    expect(progress.monthlyNeededQepik(DateTime(2027, 1, 1)), isNull);
  });
}

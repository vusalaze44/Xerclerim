import 'dart:math' as math;

class SavingsGoal {
  const SavingsGoal({required this.id, required this.name,
    required this.targetQepik, required this.deadline});
  final String id;
  final String name;
  final int targetQepik;
  final DateTime deadline;
}

class GoalMovement {
  const GoalMovement({required this.id, required this.goalId,
    required this.deltaQepik, required this.createdAt});
  final String id;
  final String goalId;
  final int deltaQepik;
  final DateTime createdAt;
}

class GoalProgress {
  const GoalProgress(this.goal, this.savedQepik);
  final SavingsGoal goal;
  final int savedQepik;
  int get remainingQepik => math.max(0, goal.targetQepik - savedQepik);
  double get fraction => (savedQepik / goal.targetQepik).clamp(0.0, 1.0).toDouble();

  /// Includes the current calendar month; past deadlines have no monthly target.
  int? monthlyNeededQepik(DateTime today) {
    if (remainingQepik == 0) return 0;
    final months = (goal.deadline.year - today.year) * 12 +
      goal.deadline.month - today.month + 1;
    if (goal.deadline.isBefore(DateTime(today.year, today.month, today.day)) || months < 1) {
      return null;
    }
    return (remainingQepik / months).ceil();
  }
}

import '../models/models.dart';

/// Fixed-ladder spaced repetition:
/// 1 day → 3 days → 1 week → 2 weeks → 1 month → 3 months, then keeps
/// doubling. Remembering climbs one rung; forgetting goes back to the start.
class Scheduler {
  static const ladder = [1, 3, 7, 14, 30, 90];

  /// Cards at or beyond this step are considered "settled" (رسخت).
  static const masteredStep = 5;

  static int intervalDays(int step) {
    if (step < ladder.length) return ladder[step];
    return ladder.last * (1 << (step - ladder.length + 1));
  }

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Calendar-based so DST changes don't shift the day.
  static DateTime addDays(DateTime t, int days) => DateTime(t.year, t.month, t.day + days);

  /// Whole calendar days from [from] to [to], unaffected by DST.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// A new card waits one day before its first review.
  static DateTime firstDue(DateTime now) => addDays(dayOf(now), intervalDays(0));

  static bool isDue(StudyCard card, DateTime now) => !dayOf(card.due).isAfter(dayOf(now));

  static void apply(StudyCard card, {required bool remembered, required DateTime now}) {
    card.step = remembered ? card.step + 1 : 0;
    if (!remembered) card.lapses++;
    card.reviews++;
    card.lastReviewed = now;
    card.due = addDays(dayOf(now), intervalDays(card.step));
  }
}

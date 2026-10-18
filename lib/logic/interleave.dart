import 'dart:math';

import '../models/models.dart';

/// Mixes cards from different lessons so that, whenever possible, two
/// consecutive cards never come from the same lesson.
///
/// Greedy: always take from the lesson with the most remaining cards that
/// isn't the one we just took from. This is optimal for avoiding adjacency.
List<StudyCard> interleave(List<StudyCard> cards, {Random? random}) {
  final rnd = random ?? Random();
  final groups = <String, List<StudyCard>>{};
  for (final c in cards) {
    groups.putIfAbsent(c.lessonId, () => []).add(c);
  }
  for (final g in groups.values) {
    g.shuffle(rnd);
  }

  final result = <StudyCard>[];
  String? last;
  while (groups.isNotEmpty) {
    final candidates = groups.keys.where((k) => k != last).toList();
    final pool = candidates.isEmpty ? groups.keys.toList() : candidates;
    pool.shuffle(rnd); // random tie-break
    final pick = pool.reduce((a, b) => groups[b]!.length > groups[a]!.length ? b : a);
    final group = groups[pick]!;
    result.add(group.removeLast());
    if (group.isEmpty) groups.remove(pick);
    last = pick;
  }
  return result;
}

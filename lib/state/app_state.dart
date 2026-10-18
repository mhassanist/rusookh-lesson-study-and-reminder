import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_prompt.dart';
import '../data/repository.dart';
import '../logic/scheduler.dart';
import '../models/models.dart';
import '../services/notification_service.dart';

/// Single source of truth. Everything is kept in memory (a personal deck is
/// small) and written through to the repository.
class AppState extends ChangeNotifier {
  AppState(this._repo, this._reminders, this._prefs);

  final Repository _repo;
  final Reminders _reminders;
  final SharedPreferences _prefs;

  List<Lesson> _lessons = [];
  List<StudyCard> _cards = [];
  List<ReviewLog> _logs = [];

  List<Lesson> get lessons => List.unmodifiable(_lessons);
  List<StudyCard> get cards => List.unmodifiable(_cards);
  List<ReviewLog> get logs => List.unmodifiable(_logs);

  Future<void> load() async {
    _lessons = await _repo.lessons();
    _cards = await _repo.cards();
    _logs = await _repo.logs();
    notifyListeners();
    await _syncReminders();
  }

  // ---------- Settings ----------

  bool get remindersEnabled => _prefs.getBool('reminders') ?? true;
  TimeOfDay get reminderTime =>
      TimeOfDay(hour: _prefs.getInt('reminderHour') ?? 20, minute: _prefs.getInt('reminderMinute') ?? 0);

  /// Ask the learner to type an answer before revealing it.
  bool get typeAnswer => _prefs.getBool('typeAnswer') ?? false;

  Future<void> setRemindersEnabled(bool value) async {
    if (value) await _reminders.requestPermission();
    await _prefs.setBool('reminders', value);
    notifyListeners();
    await _syncReminders();
  }

  Future<void> setReminderTime(TimeOfDay t) async {
    await _prefs.setInt('reminderHour', t.hour);
    await _prefs.setInt('reminderMinute', t.minute);
    notifyListeners();
    await _syncReminders();
  }

  Future<void> setTypeAnswer(bool value) async {
    await _prefs.setBool('typeAnswer', value);
    notifyListeners();
  }

  Future<void> requestPermissionOnce() async {
    if (_prefs.getBool('askedPermission') ?? false) return;
    await _prefs.setBool('askedPermission', true);
    await _reminders.requestPermission();
    await _syncReminders();
  }

  Future<void> _syncReminders() async {
    try {
      await _reminders.reschedule(_cards, enabled: remindersEnabled, time: reminderTime);
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  // ---------- Queries ----------

  Lesson? lessonById(String id) => _lessons.where((l) => l.id == id).firstOrNull;

  List<StudyCard> cardsOf(String lessonId) => _cards.where((c) => c.lessonId == lessonId).toList();

  List<StudyCard> dueCards([DateTime? now]) {
    final t = now ?? DateTime.now();
    return _cards.where((c) => Scheduler.isDue(c, t)).toList();
  }

  /// Number of cards that will be due on each of the next [days] days
  /// (index 0 = today, includes overdue).
  List<int> forecast(int days) {
    final today = Scheduler.dayOf(DateTime.now());
    final counts = List.filled(days, 0);
    for (final c in _cards) {
      final diff = Scheduler.daysBetween(today, c.due);
      final idx = diff < 0 ? 0 : diff;
      if (idx < days) counts[idx]++;
    }
    return counts;
  }

  /// Consecutive days (ending today or yesterday) with at least one review.
  int get streak {
    final days = _logs.map((l) => Scheduler.dayOf(l.at)).toSet();
    var day = Scheduler.dayOf(DateTime.now());
    if (!days.contains(day)) day = Scheduler.addDays(day, -1);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = Scheduler.addDays(day, -1);
    }
    return count;
  }

  /// Share of reviews in the last 30 days that were remembered, or null.
  double? get retention {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final recent = _logs.where((l) => l.at.isAfter(since)).toList();
    if (recent.isEmpty) return null;
    return recent.where((l) => l.remembered).length / recent.length;
  }

  int get masteredCount => _cards.where((c) => c.step >= Scheduler.masteredStep).length;

  // ---------- Mutations ----------

  Future<void> saveLesson(Lesson lesson) async {
    if (!_lessons.contains(lesson)) _lessons.insert(0, lesson);
    notifyListeners();
    await _repo.saveLesson(lesson);
  }

  Future<void> deleteLesson(Lesson lesson) async {
    _lessons.remove(lesson);
    _cards.removeWhere((c) => c.lessonId == lesson.id);
    notifyListeners();
    await _repo.deleteLesson(lesson.id);
    await _syncReminders();
  }

  StudyCard newCard(String lessonId, CardDraft d) => StudyCard(
    lessonId: lessonId,
    type: d.type,
    question: d.question,
    answer: d.answer,
    correctOption: d.correctOption,
    wrongOptions: d.wrongOptions,
    due: Scheduler.firstDue(DateTime.now()),
  );

  Future<void> saveCards(List<StudyCard> cards) async {
    for (final c in cards) {
      if (!_cards.contains(c)) _cards.add(c);
    }
    notifyListeners();
    await _repo.saveCards(cards);
    await _syncReminders();
  }

  Future<void> deleteCard(StudyCard card) async {
    _cards.remove(card);
    notifyListeners();
    await _repo.deleteCard(card.id);
    await _syncReminders();
  }

  Future<void> recordReview(StudyCard card, {required bool remembered}) async {
    final now = DateTime.now();
    Scheduler.apply(card, remembered: remembered, now: now);
    final log = ReviewLog(cardId: card.id, at: now, remembered: remembered);
    _logs.add(log);
    notifyListeners();
    await _repo.saveCards([card]);
    await _repo.addLog(log);
    await _syncReminders();
  }

  /// Saves AI output. Each lesson is merged into [targetLessonId] if given,
  /// else into an existing lesson with the same title, else created.
  /// Duplicate core points and questions are skipped, except that existing
  /// cards without choices pick them up. Returns the new cards.
  Future<List<StudyCard>> importLessons(List<AiLesson> imported, {String? targetLessonId}) async {
    final added = <StudyCard>[];
    final updated = <StudyCard>[];
    for (final ai in imported) {
      final title = ai.title.trim().isEmpty ? 'درس ${_lessons.length + 1}' : ai.title.trim();
      final lesson =
          (targetLessonId == null ? null : lessonById(targetLessonId)) ??
          _lessons.where((l) => l.title == title).firstOrNull ??
          Lesson(title: title);
      final existingCore = lesson.core.map((c) => c.text).toSet();
      lesson.core.addAll(ai.core.where((c) => existingCore.add(c.text)));
      await saveLesson(lesson);

      final existing = {for (final c in cardsOf(lesson.id)) c.question: c};
      for (final d in ai.cards) {
        final old = existing[d.question];
        if (old == null) {
          existing[d.question] = newCard(lesson.id, d);
          added.add(existing[d.question]!);
        } else if (!old.hasChoices && d.wrongOptions.isNotEmpty) {
          old
            ..correctOption = d.correctOption
            ..wrongOptions = d.wrongOptions;
          updated.add(old);
        }
      }
    }
    await saveCards([...added, ...updated]);
    return added;
  }

  // ---------- Backup ----------

  String exportJson() => jsonEncode({
    'version': 1,
    'lessons': _lessons.map((l) => l.toJson()).toList(),
    'cards': _cards.map((c) => c.toJson()).toList(),
    'logs': _logs.map((l) => l.toJson()).toList(),
  });

  Future<void> importJson(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String key) =>
        (data[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final lessons = list('lessons').map(Lesson.fromJson).toList();
    final cards = list('cards').map(StudyCard.fromJson).toList();
    final logs = list('logs').map(ReviewLog.fromJson).toList();
    await _repo.replaceAll(lessons, cards, logs);
    await load();
  }
}

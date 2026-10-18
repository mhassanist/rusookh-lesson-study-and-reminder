import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

abstract class Repository {
  Future<List<Lesson>> lessons();
  Future<List<StudyCard>> cards();
  Future<List<ReviewLog>> logs();
  Future<void> saveLesson(Lesson lesson);

  /// Also deletes the lesson's cards.
  Future<void> deleteLesson(String id);
  Future<void> saveCards(List<StudyCard> cards);
  Future<void> deleteCard(String id);
  Future<void> addLog(ReviewLog log);
  Future<void> replaceAll(List<Lesson> lessons, List<StudyCard> cards, List<ReviewLog> logs);
}

class SqliteRepository implements Repository {
  SqliteRepository._(this._db);
  final Database _db;

  static Future<SqliteRepository> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'rusookh.db'),
      version: 2,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE cards ADD COLUMN correct_option TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE cards ADD COLUMN wrong_options TEXT NOT NULL DEFAULT '[]'");
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE lessons(
            id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT, notes TEXT,
            core TEXT NOT NULL, created_at INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE cards(
            id TEXT PRIMARY KEY, lesson_id TEXT NOT NULL, type TEXT NOT NULL,
            question TEXT NOT NULL, answer TEXT NOT NULL,
            correct_option TEXT NOT NULL DEFAULT '', wrong_options TEXT NOT NULL DEFAULT '[]',
            step INTEGER NOT NULL,
            due INTEGER NOT NULL, last_reviewed INTEGER, reviews INTEGER NOT NULL,
            lapses INTEGER NOT NULL, created_at INTEGER NOT NULL)''');
        await db.execute('CREATE INDEX cards_lesson ON cards(lesson_id)');
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT, card_id TEXT NOT NULL,
            at INTEGER NOT NULL, remembered INTEGER NOT NULL)''');
      },
    );
    return SqliteRepository._(db);
  }

  @override
  Future<List<Lesson>> lessons() async {
    final rows = await _db.query('lessons', orderBy: 'created_at DESC');
    return rows
        .map(
          (r) => Lesson(
            id: r['id'] as String,
            title: r['title'] as String,
            source: r['source'] as String? ?? '',
            notes: r['notes'] as String? ?? '',
            core: (jsonDecode(r['core'] as String) as List)
                .map((e) => CorePoint.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
            createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
          ),
        )
        .toList();
  }

  @override
  Future<List<StudyCard>> cards() async {
    final rows = await _db.query('cards', orderBy: 'created_at');
    return rows
        .map(
          (r) => StudyCard(
            id: r['id'] as String,
            lessonId: r['lesson_id'] as String,
            type: QuestionType.parse(r['type'] as String),
            question: r['question'] as String,
            answer: r['answer'] as String,
            correctOption: r['correct_option'] as String? ?? '',
            wrongOptions: (jsonDecode(r['wrong_options'] as String? ?? '[]') as List).map((e) => e.toString()).toList(),
            step: r['step'] as int,
            due: DateTime.fromMillisecondsSinceEpoch(r['due'] as int),
            lastReviewed: r['last_reviewed'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(r['last_reviewed'] as int),
            reviews: r['reviews'] as int,
            lapses: r['lapses'] as int,
            createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
          ),
        )
        .toList();
  }

  @override
  Future<List<ReviewLog>> logs() async {
    final rows = await _db.query('logs', orderBy: 'at');
    return rows
        .map(
          (r) => ReviewLog(
            cardId: r['card_id'] as String,
            at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
            remembered: r['remembered'] == 1,
          ),
        )
        .toList();
  }

  Map<String, Object?> _lessonRow(Lesson l) => {
    'id': l.id,
    'title': l.title,
    'source': l.source,
    'notes': l.notes,
    'core': l.encodeCore(),
    'created_at': l.createdAt.millisecondsSinceEpoch,
  };

  Map<String, Object?> _cardRow(StudyCard c) => {
    'id': c.id,
    'lesson_id': c.lessonId,
    'type': c.type.name,
    'question': c.question,
    'answer': c.answer,
    'correct_option': c.correctOption,
    'wrong_options': jsonEncode(c.wrongOptions),
    'step': c.step,
    'due': c.due.millisecondsSinceEpoch,
    'last_reviewed': c.lastReviewed?.millisecondsSinceEpoch,
    'reviews': c.reviews,
    'lapses': c.lapses,
    'created_at': c.createdAt.millisecondsSinceEpoch,
  };

  Map<String, Object?> _logRow(ReviewLog l) => {
    'card_id': l.cardId,
    'at': l.at.millisecondsSinceEpoch,
    'remembered': l.remembered ? 1 : 0,
  };

  @override
  Future<void> saveLesson(Lesson lesson) =>
      _db.insert('lessons', _lessonRow(lesson), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteLesson(String id) => _db.transaction((txn) async {
    await txn.delete('cards', where: 'lesson_id = ?', whereArgs: [id]);
    await txn.delete('lessons', where: 'id = ?', whereArgs: [id]);
  });

  @override
  Future<void> saveCards(List<StudyCard> cards) async {
    final batch = _db.batch();
    for (final c in cards) {
      batch.insert('cards', _cardRow(c), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteCard(String id) => _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> addLog(ReviewLog log) => _db.insert('logs', _logRow(log));

  @override
  Future<void> replaceAll(List<Lesson> lessons, List<StudyCard> cards, List<ReviewLog> logs) =>
      _db.transaction((txn) async {
        await txn.delete('lessons');
        await txn.delete('cards');
        await txn.delete('logs');
        final batch = txn.batch();
        for (final l in lessons) {
          batch.insert('lessons', _lessonRow(l));
        }
        for (final c in cards) {
          batch.insert('cards', _cardRow(c));
        }
        for (final l in logs) {
          batch.insert('logs', _logRow(l));
        }
        await batch.commit(noResult: true);
      });
}

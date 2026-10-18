import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rusookh/ai/ai_prompt.dart';
import 'package:provider/provider.dart';
import 'package:rusookh/data/repository.dart';
import 'package:rusookh/main.dart';
import 'package:rusookh/models/models.dart';
import 'package:rusookh/services/notification_service.dart';
import 'package:rusookh/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryRepository implements Repository {
  final lessonsList = <Lesson>[];
  final cardsList = <StudyCard>[];
  final logsList = <ReviewLog>[];

  @override
  Future<List<Lesson>> lessons() async => [...lessonsList];
  @override
  Future<List<StudyCard>> cards() async => [...cardsList];
  @override
  Future<List<ReviewLog>> logs() async => [...logsList];
  @override
  Future<void> saveLesson(Lesson lesson) async {
    lessonsList
      ..remove(lesson)
      ..add(lesson);
  }

  @override
  Future<void> deleteLesson(String id) async {
    lessonsList.removeWhere((l) => l.id == id);
    cardsList.removeWhere((c) => c.lessonId == id);
  }

  @override
  Future<void> saveCards(List<StudyCard> cards) async {
    for (final c in cards) {
      cardsList
        ..remove(c)
        ..add(c);
    }
  }

  @override
  Future<void> deleteCard(String id) async => cardsList.removeWhere((c) => c.id == id);
  @override
  Future<void> addLog(ReviewLog log) async => logsList.add(log);
  @override
  Future<void> replaceAll(List<Lesson> l, List<StudyCard> c, List<ReviewLog> g) async {
    lessonsList
      ..clear()
      ..addAll(l);
    cardsList
      ..clear()
      ..addAll(c);
    logsList
      ..clear()
      ..addAll(g);
  }
}

void main() {
  testWidgets('due cards from two lessons can be reviewed and rescheduled', (tester) async {
    SharedPreferences.setMockInitialValues({'askedPermission': true});
    final repo = MemoryRepository();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final a = Lesson(title: 'درس أ');
    final b = Lesson(title: 'درس ب');
    repo.lessonsList.addAll([a, b]);
    repo.cardsList.addAll([
      StudyCard(lessonId: a.id, type: QuestionType.why, question: 'سؤال أ', answer: 'إجابة أ', due: yesterday),
      StudyCard(lessonId: b.id, type: QuestionType.application, question: 'سؤال ب', answer: 'إجابة ب', due: yesterday),
    ]);
    final state = AppState(repo, NoopReminders(), await SharedPreferences.getInstance());
    await state.load();

    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const RusookhApp()));
    await tester.pumpAndSettle();
    expect(find.text('2 سؤال'), findsOneWidget);

    await tester.tap(find.text('ابدأ المراجعة'));
    await tester.pumpAndSettle();

    // Forget the first, remember everything after.
    await tester.tap(find.text('اظهر الإجابة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسيت'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('اظهر الإجابة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('افتكرت'));
      await tester.pumpAndSettle();
    }

    expect(find.text('خلصت!'), findsOneWidget);
    expect(find.text('افتكرت 1 • نسيت 1'), findsOneWidget);
    expect(repo.logsList.length, 2);
    expect(state.dueCards(), isEmpty);
    expect(repo.cardsList.map((c) => c.step).toSet(), {0, 1});
  });

  test('importing AI output creates lessons, merges by title and skips duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = MemoryRepository();
    final state = AppState(repo, NoopReminders(), await SharedPreferences.getInstance());
    await state.load();
    AiLesson lesson({List<String> wrong = const []}) => AiLesson(
      title: 'الدرس',
      core: [CorePoint(kind: CorePointKind.rule, text: 'قاعدة')],
      cards: [
        (
          type: QuestionType.why,
          question: 'لماذا؟',
          answer: 'لأن',
          correctOption: wrong.isEmpty ? '' : 'صح',
          wrongOptions: wrong,
        ),
      ],
    );

    final first = await state.importLessons([lesson()]);
    expect(first.length, 1);
    expect(state.lessons.single.title, 'الدرس');
    expect(first.single.due.isAfter(DateTime.now()), isTrue, reason: 'first review is tomorrow');

    final again = await state.importLessons([lesson()]);
    expect(again, isEmpty);
    expect(state.lessons.single.core.length, 1);
    expect(repo.cardsList.length, 1);
    expect(repo.cardsList.single.hasChoices, isFalse);

    // Re-importing with choices back-fills them onto the existing card.
    expect(
      await state.importLessons([
        lesson(wrong: ['غلط']),
      ]),
      isEmpty,
    );
    expect(repo.cardsList.single.correctOption, 'صح');
  });

  testWidgets('choices are shown on demand and the pick is marked', (tester) async {
    SharedPreferences.setMockInitialValues({'askedPermission': true});
    final repo = MemoryRepository();
    final lesson = Lesson(title: 'درس');
    repo.lessonsList.add(lesson);
    repo.cardsList.add(
      StudyCard(
        lessonId: lesson.id,
        type: QuestionType.definition,
        question: 'ما المقصود بالاسترجاع؟',
        answer: 'محاولة تذكر المعلومة دون النظر إليها.',
        correctOption: 'التذكر دون النظر',
        wrongOptions: ['إعادة القراءة', 'التلخيص الطويل', 'النسخ'],
        due: DateTime.now(),
      ),
    );
    final state = AppState(repo, NoopReminders(), await SharedPreferences.getInstance());
    await state.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const RusookhApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ المراجعة'));
    await tester.pumpAndSettle();

    expect(find.text('التذكر دون النظر'), findsNothing, reason: 'question comes first');
    expect(find.text('نسيت'), findsNothing);

    await tester.tap(find.text('اظهر الاختيارات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة القراءة'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('محاولة تذكر المعلومة دون النظر إليها.'), findsNothing, reason: 'written answer is optional');

    await tester.tap(find.text('اظهر الإجابة'));
    await tester.pumpAndSettle();
    expect(find.text('محاولة تذكر المعلومة دون النظر إليها.'), findsOneWidget);
    await tester.tap(find.text('نسيت'));
    await tester.pumpAndSettle();
    expect(repo.logsList.single.remembered, isFalse);
  });
}

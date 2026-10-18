import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/scheduler.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: context.read<AppState>().exportJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('النسخة الاحتياطية اتنسخت. احفظها في ملاحظة أو ابعتها لنفسك.')));
  }

  Future<void> _import(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استرجاع نسخة احتياطية'),
        content: const Text('انسخ النسخة الاحتياطية الأول. كل البيانات الحالية هتتستبدل بيها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استرجع من الحافظة')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      await state.importJson(data?.text ?? '');
      messenger.showSnackBar(const SnackBar(content: Text('تم الاسترجاع')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('الحافظة مفيهاش نسخة احتياطية صحيحة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('تذكير المراجعة'),
            subtitle: const Text('إشعار يومي في الأيام اللي فيها أسئلة عليها الدور'),
            value: state.remindersEnabled,
            onChanged: state.setRemindersEnabled,
          ),
          ListTile(
            enabled: state.remindersEnabled,
            title: const Text('ميعاد التذكير'),
            trailing: Text(state.reminderTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: state.reminderTime);
              if (t != null) await state.setReminderTime(t);
            },
          ),
          SwitchListTile(
            title: const Text('اكتب إجابتك الأول'),
            subtitle: const Text('خانة تكتب فيها اللي فاكره قبل ما تشوف الإجابة — استرجاع أقوى'),
            value: state.typeAnswer,
            onChanged: state.setTypeAnswer,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('نسخة احتياطية'),
            subtitle: const Text('انسخ كل بياناتك للحافظة'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('استرجاع نسخة احتياطية'),
            onTap: () => _import(context),
          ),
          const Divider(),
          ListTile(
            title: const Text('فترات المراجعة'),
            subtitle: Text(
              '${Scheduler.ladder.map((d) => '$d').join(' ← ')} يوم، وبعدها الفترة بتتضاعف. '
              'لو نسيت سؤال يرجع لأول الدورة.',
            ),
          ),
        ],
      ),
    );
  }
}

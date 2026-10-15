import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/Database_Services.dart';
import 'commonWidgets.dart';

const String _lastBackupKey = 'last_backup';
const String _snoozeKey = 'backup_snooze_until';
const String _reminderKey = 'backup_reminder';
const int backupReminderDays = 30;

// Exports the database and opens the share sheet. The backup date is
// remembered only when the user actually shared/saved the file.
Future<bool> shareBackup(BuildContext context, {String subject = 'نسخة احتياطية - محفظتي'}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await DatabaseHelper().exportBackup();
    final result = await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: subject));
    if (result.status == ShareResultStatus.success) {
      await DatabaseHelper().setSetting(_lastBackupKey, DatabaseHelper().formatDate(DateTime.now()));
      return true;
    }
    return false;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذر إنشاء النسخة الاحتياطية')));
    return false;
  }
}

// Asks for confirmation, lets the user pick a backup file and restores it.
// Returns true when the data was replaced.
Future<bool> restoreBackupFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await confirmDialog(
    context,
    title: 'استعادة نسخة احتياطية',
    message: 'سيتم استبدال كل البيانات الحالية بالبيانات الموجودة في النسخة المختارة. هل تريد المتابعة؟',
    confirmLabel: 'استعادة',
  );
  if (!confirmed) return false;
  try {
    final file = await FilePicker.pickFile();
    if (file == null) return false;
    final restored = await DatabaseHelper().restoreBackup(await file.readAsBytes());
    if (!restored) {
      messenger.showSnackBar(
        const SnackBar(content: Text('هذا الملف ليس نسخة احتياطية صالحة، لم يتم تغيير أي شيء')),
      );
      return false;
    }
    // The backup carries its own settings, e.g. the currency
    currencySymbol = await DatabaseHelper().getSetting('currency') ?? '\$';
    await loadCustomCategories();
    messenger.showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح')));
    return true;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذرت استعادة النسخة الاحتياطية')));
    return false;
  }
}

Future<String?> lastBackupDate() => DatabaseHelper().getSetting(_lastBackupKey);

Future<bool> isBackupReminderOn() async => await DatabaseHelper().getSetting(_reminderKey) != '0';

Future<void> setBackupReminder(bool on) => DatabaseHelper().setSetting(_reminderKey, on ? '1' : '0');

// Hides the reminder for a week.
Future<void> snoozeBackupReminder() => DatabaseHelper().setSetting(
      _snoozeKey,
      DatabaseHelper().formatDate(DateTime.now().add(const Duration(days: 7))),
    );

// When the reminder should show: days since the last backup, or -1 if there
// was never one. null means no reminder right now.
Future<int?> backupReminderDue() async {
  if (!await isBackupReminderOn()) return null;
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final snooze = DateTime.tryParse(await DatabaseHelper().getSetting(_snoozeKey) ?? '');
  if (snooze != null && today.isBefore(DateTime.utc(snooze.year, snooze.month, snooze.day))) return null;
  final last = DateTime.tryParse(await lastBackupDate() ?? '');
  if (last == null) return -1;
  final days = today.difference(DateTime.utc(last.year, last.month, last.day)).inDays;
  return days >= backupReminderDays ? days : null;
}

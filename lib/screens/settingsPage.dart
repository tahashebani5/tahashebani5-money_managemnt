import 'package:flutter/material.dart';
import '../services/Database_Services.dart';
import '../services/appLock.dart';
import '../widgets/backupActions.dart';
import '../widgets/commonWidgets.dart';
import '../widgets/pinPad.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() => _SettingspageState();
}

class _SettingspageState extends State<Settingspage> {
  bool _loaded = false;
  bool _lock = false;
  bool _biometric = false;
  bool _canUseBiometrics = false;
  bool _reminder = true;
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lock = await AppLock.isEnabled();
    final biometric = await AppLock.isBiometricEnabled();
    final canUse = await AppLock.canUseBiometrics();
    final reminder = await isBackupReminderOn();
    final last = await lastBackupDate();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _lock = lock;
      _biometric = biometric;
      _canUseBiometrics = canUse;
      _reminder = reminder;
      _lastBackup = last;
    });
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final agreed = await confirmDialog(
        context,
        title: 'تفعيل قفل التطبيق',
        message: 'سيُطلب منك رمز من 4 أرقام كلما فتحت التطبيق.\n\n'
            'مهم: إذا نسيت الرمز (ولم تفعّل البصمة) لن تتمكن من فتح التطبيق إلا بحذف بياناته، '
            'لذلك احتفظ بنسخة احتياطية.',
        confirmLabel: 'متابعة',
      );
      if (!agreed || !mounted) return;
      if (await showPinSetup(context)) _showMessage('تم تفعيل قفل التطبيق');
    } else {
      if (!await showPinVerify(context, title: 'إيقاف القفل')) return;
      await AppLock.disable();
      _showMessage('تم إيقاف قفل التطبيق');
    }
    await _load();
  }

  Future<void> _changePin() async {
    if (!await showPinVerify(context, title: 'تغيير الرمز')) return;
    if (!mounted) return;
    if (await showPinSetup(context)) _showMessage('تم تغيير الرمز');
  }

  Future<void> _toggleBiometric(bool on) async {
    if (on && !await AppLock.authenticateWithBiometrics()) return;
    await AppLock.setBiometricEnabled(on);
    await _load();
  }

  Future<void> _chooseCurrency() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('العملة'),
        children: [
          for (final symbol in currencyChoices)
            ListTile(
              leading: Icon(
                symbol == currencySymbol ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              ),
              title: Text(ltr(symbol)),
              onTap: () => Navigator.of(context).pop(symbol),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == currencySymbol) return;
    await DatabaseHelper().setSetting('currency', chosen);
    setState(() => currencySymbol = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SectionHeader(title: 'الأمان'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.lock_outline),
                        title: const Text('قفل التطبيق برمز'),
                        subtitle: const Text('اطلب رمزاً من 4 أرقام عند فتح التطبيق'),
                        value: _lock,
                        onChanged: _toggleLock,
                      ),
                      if (_lock) ...[
                        ListTile(
                          leading: const Icon(Icons.password),
                          title: const Text('تغيير الرمز'),
                          onTap: _changePin,
                        ),
                        SwitchListTile(
                          secondary: const Icon(Icons.fingerprint),
                          title: const Text('الفتح بالبصمة'),
                          subtitle: Text(
                            _canUseBiometrics
                                ? 'استخدم بصمة الإصبع أو الوجه بدلاً من الرمز'
                                : 'لا توجد بصمة مسجلة على هذا الجهاز',
                          ),
                          value: _biometric,
                          onChanged: _canUseBiometrics ? _toggleBiometric : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SectionHeader(title: 'العرض'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('العملة'),
                    trailing: Text(ltr(currencySymbol), style: const TextStyle(fontSize: 18)),
                    onTap: _chooseCurrency,
                  ),
                ),
                const SectionHeader(title: 'النسخ الاحتياطي'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('آخر نسخة احتياطية'),
                        subtitle: Text(_lastBackup == null ? 'لم تُحفظ أي نسخة بعد' : friendlyDate(_lastBackup!)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.upload_file),
                        title: const Text('نسخ احتياطي الآن'),
                        subtitle: const Text('احفظ الملف في Drive أو أرسله لنفسك'),
                        onTap: () async {
                          if (await shareBackup(context)) await _load();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.restore),
                        title: const Text('استعادة نسخة'),
                        onTap: () async {
                          if (await restoreBackupFlow(context)) await _load();
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('تذكير بالنسخ الاحتياطي'),
                        subtitle: Text('ذكّرني إذا مرّ $backupReminderDays يوماً بدون نسخة'),
                        value: _reminder,
                        onChanged: (on) async {
                          await setBackupReminder(on);
                          await _load();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    'قفل التطبيق يمنع الآخرين من فتحه على هاتفك. البيانات نفسها محفوظة على الهاتف فقط.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

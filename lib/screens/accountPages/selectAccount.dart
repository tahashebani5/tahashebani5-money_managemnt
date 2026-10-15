import 'package:flutter/material.dart';
import 'package:money_management/screens/accountPages/createAccount.dart';
import 'package:money_management/screens/homePages/accountShell.dart';
import 'package:money_management/screens/settingsPage.dart';
import '../../services/Database_Services.dart';
import '../../widgets/backupActions.dart';
import '../../widgets/commonWidgets.dart';

class Selectaccount extends StatefulWidget {
  const Selectaccount({super.key});

  @override
  State<Selectaccount> createState() => _SelectaccountState();
}

class _SelectaccountState extends State<Selectaccount> {
  // Pushes a page and reloads the list (balances, currency, reminder) on return.
  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => page))
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Future<List<dynamic>> _load() async {
    // Add any recurring expenses that became due, then show the list
    try {
      final added = await DatabaseHelper().processDueRecurring();
      if (added.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('أُضيفت المصاريف الثابتة: ${added.toSet().join('، ')}')),
          );
        });
      }
    } catch (_) {
      // Never block the accounts list because of a recurring item
    }
    return [await DatabaseHelper().getAccounts(), await backupReminderDue()];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحسابات'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(const Settingspage()),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final accounts = snapshot.data![0] as List<Map<String, dynamic>>;
          final reminderDays = snapshot.data![1] as int?;
          if (accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'لا توجد حسابات بعد',
              subtitle: 'اضغط على "حساب جديد" لإضافة أول حساب',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 96),
            children: [
              if (reminderDays != null) _backupReminder(reminderDays),
              for (final account in accounts)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: const Icon(Icons.account_balance_wallet),
                    ),
                    title: Text(
                      account['account_name'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('الرصيد'),
                    trailing: Text(
                      moneyText(account['account_balance']),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    onTap: () => _open(Accountshell(account_id: account['account_id'])),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const Createaccount()),
        icon: const Icon(Icons.add),
        label: const Text('حساب جديد'),
      ),
    );
  }

  // Card shown when no backup was made for a while (see backupReminderDue).
  Widget _backupReminder(int days) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    days < 0
                        ? 'لم تحفظ أي نسخة احتياطية بعد'
                        : 'آخر نسخة احتياطية كانت قبل $days يوماً',
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 36),
              child: Text(
                'احفظ نسخة في Drive أو أرسلها لنفسك حتى لا تضيع بياناتك إذا تغيّر الهاتف.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await snoozeBackupReminder();
                    if (mounted) setState(() {});
                  },
                  child: const Text('لاحقاً'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await shareBackup(context);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('نسخ الآن'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

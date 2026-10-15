import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:money_management/screens/accountPages/createAccount.dart';
import 'package:money_management/screens/homePages/accountShell.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

class Selectaccount extends StatefulWidget {
  const Selectaccount({super.key});

  @override
  State<Selectaccount> createState() => _SelectaccountState();
}

class _SelectaccountState extends State<Selectaccount> {
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _backup() async {
    try {
      final path = await DatabaseHelper().exportBackup();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: 'نسخة احتياطية - إدارة الأموال'),
      );
    } catch (e) {
      _showMessage('تعذر إنشاء النسخة الاحتياطية');
    }
  }

  Future<void> _restore() async {
    final confirmed = await confirmDialog(
      context,
      title: 'استعادة نسخة احتياطية',
      message: 'سيتم استبدال كل البيانات الحالية بالبيانات الموجودة في النسخة المختارة. هل تريد المتابعة؟',
      confirmLabel: 'استعادة',
    );
    if (!confirmed) return;

    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final restored = await DatabaseHelper().restoreBackup(await file.readAsBytes());
      if (restored) {
        _showMessage('تمت استعادة البيانات بنجاح');
        setState(() {});
      } else {
        _showMessage('هذا الملف ليس نسخة احتياطية صالحة، لم يتم تغيير أي شيء');
      }
    } catch (e) {
      _showMessage('تعذرت استعادة النسخة الاحتياطية');
    }
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

  void _openCreateAccount() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const Createaccount()))
        .then((_) {
          setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحسابات'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'backup') _backup();
              if (value == 'restore') _restore();
              if (value == 'currency') _chooseCurrency();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'currency',
                child: ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('العملة'),
                  trailing: Text(ltr(currencySymbol)),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('نسخ احتياطي'),
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('استعادة نسخة'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'لا توجد حسابات بعد',
              subtitle: 'اضغط على "حساب جديد" لإضافة أول حساب',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 96),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
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
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => Accountshell(
                              account_id: account['account_id'],
                            ),
                          ),
                        )
                        .then((_) {
                          // Balance may have changed inside the account
                          setState(() {});
                        });
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateAccount,
        icon: const Icon(Icons.add),
        label: const Text('حساب جديد'),
      ),
    );
  }
}

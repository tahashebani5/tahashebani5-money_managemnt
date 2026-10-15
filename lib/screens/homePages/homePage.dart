import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:money_management/screens/homePages/billPages/billPage.dart';
import 'package:money_management/screens/homePages/billPages/previesBillsPage.dart';
import 'package:money_management/screens/homePages/depositePages/depositePage.dart';
import 'package:money_management/screens/homePages/searchPage.dart';
import 'package:money_management/screens/homePages/statisticsPage.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

class Homepage extends StatefulWidget {
  final acccount_id;
  const Homepage({Key? key, required this.acccount_id}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  Future<List<dynamic>> _load() {
    return Future.wait([
      DatabaseHelper().getAccount(widget.acccount_id),
      DatabaseHelper().getMonthSummary(widget.acccount_id),
      DatabaseHelper().getRecentActivity(widget.acccount_id),
    ]);
  }

  // Opens a page and reloads the balance and activity when coming back.
  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => page))
        .then((_) {
          setState(() {});
        });
  }

  Future<void> _openTodayBill() async {
    final today = DatabaseHelper().formatDate(DateTime.now());
    final billId = await DatabaseHelper().getOrCreateBill(widget.acccount_id, today);
    if (!mounted) return;
    _open(Billpage(account_id: widget.acccount_id, date: today, bill_id: billId));
  }

  // Deleting needs the account name typed in, and a backup is shared first.
  Future<void> _deleteAccount(String name) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('حذف الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيتم حذف الحساب "$name" مع كل فواتيره وإيداعاته نهائياً.\n\n'
                'قبل الحذف ستظهر نافذة المشاركة لحفظ نسخة احتياطية.\n\n'
                'للتأكيد اكتب اسم الحساب:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(hintText: name),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: controller.text.trim() == name.trim()
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('حذف نهائياً'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await DatabaseHelper().exportBackup();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: 'نسخة احتياطية قبل حذف $name'),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء النسخة الاحتياطية، لم يتم حذف الحساب')),
      );
      return;
    }
    await DatabaseHelper().deleteAccount(widget.acccount_id);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('تم حذف الحساب "$name"')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data?[0] == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snapshot.error ?? 'الحساب غير موجود'}')),
          );
        }
        final account = snapshot.data![0] as Map<String, dynamic>;
        final summary = snapshot.data![1] as Map<String, double>;
        final recent = snapshot.data![2] as List<Map<String, dynamic>>;

        return Scaffold(
          appBar: AppBar(
            title: Text(account['account_name'] as String),
            actions: [
              IconButton(
                tooltip: 'بحث',
                icon: const Icon(Icons.search),
                onPressed: () => _open(Searchpage(account_id: widget.acccount_id)),
              ),
              IconButton(
                tooltip: 'الإحصائيات',
                icon: const Icon(Icons.bar_chart),
                onPressed: () => _open(Statisticspage(account_id: widget.acccount_id)),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteAccount(account['account_name'] as String);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                      title: Text(
                        'حذف الحساب',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SummaryCard(
                label: 'الرصيد الحالي',
                value: moneyText(account['account_balance']),
                footer: Row(
                  children: [
                    Expanded(
                      child: _MonthStat(
                        icon: Icons.arrow_upward,
                        label: 'مصروف هذا الشهر',
                        value: moneyText(summary['spent']),
                      ),
                    ),
                    Expanded(
                      child: _MonthStat(
                        icon: Icons.arrow_downward,
                        label: 'إيداع هذا الشهر',
                        value: moneyText(summary['deposited']),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _ActionTile(
                      icon: Icons.receipt_long,
                      label: 'فاتورة اليوم',
                      onTap: _openTodayBill,
                    ),
                    _ActionTile(
                      icon: Icons.history,
                      label: 'الفواتير السابقة',
                      onTap: () => _open(Previesbillspage(account_id: widget.acccount_id)),
                    ),
                    _ActionTile(
                      icon: Icons.add_card,
                      label: 'إضافة رصيد',
                      onTap: () => _open(Depositepage(account_id: widget.acccount_id)),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'آخر العمليات'),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد عمليات بعد')),
                ),
              for (final activity in recent) _activityTile(activity),
            ],
          ),
        );
      },
    );
  }

  Widget _activityTile(Map<String, dynamic> activity) {
    final isBill = activity['type'] == 'bill';
    final color = isBill ? Colors.red.shade400 : Colors.green.shade600;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(isBill ? Icons.shopping_bag_outlined : Icons.savings_outlined),
        ),
        title: Text(isBill ? 'فاتورة' : 'إيداع'),
        subtitle: Text(activity['date'].toString()),
        trailing: Text(
          '${isBill ? '-' : '+'}${moneyText(activity['amount'])}',
          textDirection: TextDirection.ltr,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onTap: isBill
            ? () => _open(Billpage(
                  account_id: widget.acccount_id,
                  date: activity['date'],
                  bill_id: activity['id'],
                ))
            : null,
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MonthStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: onPrimary.withValues(alpha: 0.2),
          child: Icon(icon, size: 18, color: onPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: onPrimary.withValues(alpha: 0.85), fontSize: 12)),
              Text(value, style: TextStyle(color: onPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        color: scheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, size: 32, color: scheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:money_management/screens/homePages/billPages/billPage.dart';
import 'package:money_management/screens/homePages/billPages/previesBillsPage.dart';
import 'package:money_management/screens/homePages/depositePages/depositePage.dart';
import 'package:money_management/screens/homePages/searchPage.dart';
import 'package:money_management/screens/homePages/statisticsPage.dart';
import 'package:money_management/screens/homePages/transferPage.dart';
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
                  if (value == 'budget') _editBudget((account['monthly_budget'] as num?)?.toDouble());
                  if (value == 'transfer') _open(Transferpage(account_id: widget.acccount_id));
                  if (value == 'delete') _deleteAccount(account['account_name'] as String);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'budget',
                    child: ListTile(
                      leading: Icon(Icons.savings),
                      title: Text('الميزانية الشهرية'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'transfer',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz),
                      title: Text('تحويل إلى حساب آخر'),
                    ),
                  ),
                  const PopupMenuDivider(),
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
                footer: Column(
                  children: [
                    Row(
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
                    if (((account['monthly_budget'] as num?) ?? 0) > 0)
                      _BudgetProgress(
                        budget: (account['monthly_budget'] as num).toDouble(),
                        spent: summary['spent'] ?? 0,
                      ),
                  ],
                ),
              ),
              BudgetWarning(
                budget: (account['monthly_budget'] as num?)?.toDouble(),
                spent: summary['spent'] ?? 0,
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
    final type = activity['type'];
    final note = activity['note'] as String?;
    final hasNote = note != null && note.isNotEmpty;
    final bool outgoing = type == 'bill' || type == 'transfer_out';
    final Color color;
    final IconData icon;
    final String title;
    VoidCallback? onTap;
    switch (type) {
      case 'bill':
        color = Colors.red.shade400;
        icon = Icons.shopping_bag_outlined;
        title = 'فاتورة';
        onTap = () => _open(Billpage(
              account_id: widget.acccount_id,
              date: activity['date'],
              bill_id: activity['id'],
            ));
      case 'deposite':
        color = Colors.green.shade600;
        icon = Icons.savings_outlined;
        title = (note != null && note.isNotEmpty) ? note : 'إيداع';
      default:
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.swap_horiz;
        title = type == 'transfer_out'
            ? 'تحويل إلى ${activity['other_account'] ?? 'حساب محذوف'}'
            : 'تحويل من ${activity['other_account'] ?? 'حساب محذوف'}';
        onTap = () => _deleteTransfer(activity);
    }
    final subtitle = [
      activity['date'].toString(),
      if (hasNote && type != 'deposite') note,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          '${outgoing ? '-' : '+'}${moneyText(activity['amount'])}',
          textDirection: TextDirection.ltr,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _deleteTransfer(Map<String, dynamic> activity) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف التحويل',
      message: 'هل تريد حذف هذا التحويل بقيمة ${moneyText(activity['amount'])}؟ '
          'سيعود المبلغ إلى الحساب الذي خرج منه.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;
    await DatabaseHelper().deleteTransfer(activity['id']);
    if (mounted) setState(() {});
  }

  Future<void> _editBudget(double? current) async {
    final controller = TextEditingController(
      text: current == null ? '' : DatabaseHelper().formatMoney(current).replaceAll(',', ''),
    );
    // Returns the new budget, 0 to remove it, or null when cancelled
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الميزانية الشهرية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('حدد أقصى مبلغ تريد صرفه في الشهر. سيظهر تنبيه عند الوصول إلى 80%.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
          ],
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('إزالة الميزانية'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) Navigator.of(context).pop(value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await DatabaseHelper().setMonthlyBudget(widget.acccount_id, result > 0 ? result : null);
    if (mounted) setState(() {});
  }
}

class _BudgetProgress extends StatelessWidget {
  final double budget;
  final double spent;
  const _BudgetProgress({required this.budget, required this.spent});

  @override
  Widget build(BuildContext context) {
    const onPrimary = onBrand;
    final ratio = spent / budget;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الميزانية: ${moneyText(spent)} من ${moneyText(budget)} (${ltr('${(ratio * 100).round()}%')})',
            style: TextStyle(color: onPrimary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: onPrimary.withValues(alpha: 0.25),
              color: onPrimary,
            ),
          ),
        ],
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
    const onPrimary = onBrand;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Bright teal tiles in light mode; quiet dark tiles with teal icons in dark mode
    final background = dark ? scheme.surfaceContainerHigh : scheme.primaryContainer;
    final iconColor = dark ? scheme.primary : scheme.onPrimaryContainer;
    final textColor = dark ? scheme.onSurface : scheme.onPrimaryContainer;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        color: background,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, size: 32, color: iconColor),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
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

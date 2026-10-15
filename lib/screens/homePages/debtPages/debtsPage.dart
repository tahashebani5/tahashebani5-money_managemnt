import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/debtPages/addDebtPage.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

const Color _oweColor = Color(0xFFE53935);
const Color _owedColor = Color(0xFF43A047);

bool _isIOwe(Map<String, dynamic> debt) => debt['direction'] == DatabaseHelper.debtIOwe;
double _left(Map<String, dynamic> debt) =>
    (debt['amount'] as num).toDouble() - (debt['paid'] as num).toDouble();

class Debtspage extends StatefulWidget {
  final int account_id;
  const Debtspage({super.key, required this.account_id});

  @override
  State<Debtspage> createState() => _DebtspageState();
}

class _DebtspageState extends State<Debtspage> {
  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page)).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الديون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(Adddebtpage(account_id: widget.account_id)),
        icon: const Icon(Icons.add),
        label: const Text('دين جديد'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getDebts(widget.account_id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final debts = snapshot.data!;
          if (debts.isEmpty) {
            return const EmptyState(
              icon: Icons.handshake_outlined,
              title: 'لا توجد ديون',
              subtitle: 'سجّل ما أقرضته للآخرين أو ما اقترضته منهم، وتابع السداد',
            );
          }
          final open = debts.where((d) => d['settled'] != 1).toList();
          final settled = debts.where((d) => d['settled'] == 1).toList();
          final owedToMe = open.where((d) => !_isIOwe(d)).fold<double>(0, (s, d) => s + _left(d));
          final iOwe = open.where(_isIOwe).fold<double>(0, (s, d) => s + _left(d));
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    _TotalTile(label: 'لي عند الآخرين', value: owedToMe, color: _owedColor),
                    _TotalTile(label: 'عليّ للآخرين', value: iOwe, color: _oweColor),
                  ],
                ),
              ),
              if (open.isNotEmpty) const SectionHeader(title: 'ديون مفتوحة'),
              for (final debt in open) _debtCard(debt),
              if (settled.isNotEmpty) const SectionHeader(title: 'ديون مسددة'),
              for (final debt in settled) _debtCard(debt),
            ],
          );
        },
      ),
    );
  }

  Widget _debtCard(Map<String, dynamic> debt) {
    final scheme = Theme.of(context).colorScheme;
    final iOwe = _isIOwe(debt);
    final color = iOwe ? _oweColor : _owedColor;
    final amount = (debt['amount'] as num).toDouble();
    final paid = (debt['paid'] as num).toDouble();
    final settled = debt['settled'] == 1;
    final due = debt['due_date'] as String?;
    final overdue = !settled && due != null && due.compareTo(DatabaseHelper().formatDate(DateTime.now())) < 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(Debtdetailpage(debt_id: debt['debt_id'], account_id: widget.account_id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    foregroundColor: color,
                    child: Icon(iOwe ? Icons.call_received : Icons.call_made),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debt['person'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          [
                            iOwe ? 'عليّ' : 'لي',
                            friendlyDate(debt['debt_date'] as String),
                            if (settled) 'مسدد',
                          ].join(' · '),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    moneyText(settled ? amount : amount - paid),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: settled ? scheme.onSurfaceVariant : color,
                      decoration: settled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              if (!settled) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0,
                    minHeight: 6,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'المسدد ${moneyText(paid)} من ${moneyText(amount)}',
                    if (due != null) '${overdue ? 'تأخر السداد منذ' : 'موعد السداد'} ${friendlyDate(due)}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: overdue ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _TotalTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(moneyText(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class Debtdetailpage extends StatefulWidget {
  final int debt_id;
  final int account_id;
  const Debtdetailpage({super.key, required this.debt_id, required this.account_id});

  @override
  State<Debtdetailpage> createState() => _DebtdetailpageState();
}

class _DebtdetailpageState extends State<Debtdetailpage> {
  Future<List<dynamic>> _load() async {
    final debts = await DatabaseHelper().getDebts(widget.account_id);
    final debt = debts.where((d) => d['debt_id'] == widget.debt_id);
    return [debt.isEmpty ? null : debt.first, await DatabaseHelper().getDebtPayments(widget.debt_id)];
  }

  Future<void> _addPayment(Map<String, dynamic> debt) async {
    final left = _left(debt);
    final controller = TextEditingController(text: DatabaseHelper().formatMoney(left).replaceAll(',', ''));
    final iOwe = _isIOwe(debt);
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(iOwe ? 'دفعتُ جزءاً من الدين' : 'استلمتُ جزءاً من الدين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              iOwe ? 'سيُخصم المبلغ من رصيد الحساب.' : 'سيُضاف المبلغ إلى رصيد الحساب.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              decoration: InputDecoration(labelText: 'المبلغ', helperText: 'المتبقي ${moneyText(left)}'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0 && value <= left + 0.001) Navigator.of(context).pop(value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    await DatabaseHelper().addDebtPayment(widget.debt_id, amount, DatabaseHelper().formatDate(DateTime.now()));
    if (mounted) setState(() {});
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف الدفعة',
      message: 'هل تريد حذف دفعة ${moneyText(payment['amount'])}؟ سيُعاد الرصيد كما كان قبلها.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;
    await DatabaseHelper().deleteDebtPayment(payment['payment_id']);
    if (mounted) setState(() {});
  }

  Future<void> _deleteDebt(Map<String, dynamic> debt) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف الدين',
      message: 'سيُحذف دين "${debt['person']}" مع كل دفعاته، وتُلغى كل تغييرات الرصيد التي سببها.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;
    await DatabaseHelper().deleteDebt(widget.debt_id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final debt = snapshot.data![0] as Map<String, dynamic>?;
        final payments = snapshot.data![1] as List<Map<String, dynamic>>;
        if (debt == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('هذا الدين غير موجود')));
        }
        final iOwe = _isIOwe(debt);
        final amount = (debt['amount'] as num).toDouble();
        final paid = (debt['paid'] as num).toDouble();
        final settled = debt['settled'] == 1;
        final note = debt['note'] as String?;
        return Scaffold(
          appBar: AppBar(
            title: Text(debt['person'] as String),
            actions: [
              IconButton(
                tooltip: 'حذف الدين',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteDebt(debt),
              ),
            ],
          ),
          floatingActionButton: settled
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addPayment(debt),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(iOwe ? 'تسجيل دفعة' : 'تسجيل استلام'),
                ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryCard(
                label: settled ? 'تم السداد بالكامل' : (iOwe ? 'المتبقي عليّ' : 'المتبقي لي'),
                value: moneyText(settled ? amount : amount - paid),
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0,
                        minHeight: 8,
                        color: onBrand,
                        backgroundColor: onBrand.withValues(alpha: 0.25),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المبلغ الأصلي ${moneyText(amount)} · المسدد ${moneyText(paid)}',
                      style: TextStyle(color: onBrand.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('التاريخ'),
                      trailing: Text(friendlyDate(debt['debt_date'] as String)),
                    ),
                    if (debt['due_date'] != null)
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('موعد السداد'),
                        trailing: Text(friendlyDate(debt['due_date'] as String)),
                      ),
                    if (note != null && note.isNotEmpty)
                      ListTile(leading: const Icon(Icons.notes), title: Text(note)),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(
                        debt['counts_in_balance'] == 1
                            ? 'سُجّل المبلغ في رصيد الحساب عند الإنشاء'
                            : 'لم يُسجّل المبلغ في الرصيد عند الإنشاء',
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeader(title: iOwe ? 'الدفعات' : 'المبالغ المستلمة'),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد دفعات بعد', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                ),
              for (final payment in payments)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(moneyText(payment['amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(friendlyDate(payment['payment_date'] as String)),
                    trailing: IconButton(
                      tooltip: 'حذف الدفعة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deletePayment(payment),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

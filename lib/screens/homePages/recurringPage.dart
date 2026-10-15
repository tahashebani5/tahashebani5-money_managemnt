import 'package:flutter/material.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

// Monthly expenses (rent, subscriptions...) that are added automatically.
class Recurringpage extends StatefulWidget {
  final int account_id;
  const Recurringpage({super.key, required this.account_id});

  @override
  State<Recurringpage> createState() => _RecurringpageState();
}

class _RecurringpageState extends State<Recurringpage> {
  void _openForm([Map<String, dynamic>? recurring]) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (context) => _RecurringForm(account_id: widget.account_id, recurring: recurring),
        ))
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف الثابتة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('مصروف ثابت جديد'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getRecurring(widget.account_id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat,
              title: 'لا توجد مصاريف ثابتة',
              subtitle: 'أضف الإيجار أو الاشتراكات، وستُضاف تلقائياً كل شهر في يومها',
            );
          }
          final monthly = list
              .where((r) => r['active'] == 1)
              .fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryCard(
                label: 'مجموع المصاريف الثابتة شهرياً',
                value: moneyText(monthly),
                footer: Text(
                  'تُضاف تلقائياً إلى فاتورة يومها وتُخصم من الرصيد',
                  style: TextStyle(color: onBrand.withValues(alpha: 0.85)),
                ),
              ),
              for (final r in list)
                Card(
                  child: ListTile(
                    onTap: () => _openForm(r),
                    leading: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                      child: Icon(categoryOf(r['category'] as String?).icon),
                    ),
                    title: Text(r['name'] as String, style: const TextStyle(fontSize: 18)),
                    subtitle: Text(
                      r['active'] == 1
                          ? '${moneyText(r['amount'])} · يوم ${r['day_of_month']} من كل شهر · القادم ${friendlyDate(r['next_date'] as String)}'
                          : '${moneyText(r['amount'])} · متوقف',
                    ),
                    trailing: Switch(
                      value: r['active'] == 1,
                      onChanged: (on) async {
                        await DatabaseHelper().setRecurringActive(r['recurring_id'] as int, on);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecurringForm extends StatefulWidget {
  final int account_id;
  final Map<String, dynamic>? recurring;
  const _RecurringForm({required this.account_id, this.recurring});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  int _day = DateTime.now().day;
  String? _category;
  bool _saving = false;

  bool get _isEdit => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    if (r != null) {
      _name.text = r['name'] as String;
      _amount.text = DatabaseHelper().formatMoney(r['amount']).replaceAll(',', '');
      _day = r['day_of_month'] as int;
      _category = r['category'] as String?;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final values = {
      'name': _name.text.trim(),
      'amount': double.parse(_amount.text),
      'category': _category,
      'day_of_month': _day,
    };
    final db = DatabaseHelper();
    if (_isEdit) {
      final r = widget.recurring!;
      await db.updateRecurring(r['recurring_id'] as int, {
        ...values,
        // A different day restarts the schedule from today
        if (r['day_of_month'] != _day) 'next_date': db.firstRecurringDate(_day),
      });
    } else {
      await db.addRecurring({
        ...values,
        'account_id': widget.account_id,
        'next_date': db.firstRecurringDate(_day),
        'active': 1,
      });
      // Add it right away if its day is today
      await db.processDueRecurring(account_id: widget.account_id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف المصروف الثابت',
      message: 'لن يُضاف "${widget.recurring!['name']}" بعد الآن. المصاريف التي أُضيفت سابقاً تبقى في فواتيرها.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;
    await DatabaseHelper().deleteRecurring(widget.recurring!['recurring_id'] as int);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = DatabaseHelper().firstRecurringDate(_day);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل مصروف ثابت' : 'مصروف ثابت جديد'),
        actions: [
          if (_isEdit) IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                hintText: 'مثلاً: الإيجار، الإنترنت',
                prefixIcon: Icon(Icons.event_repeat),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              decoration: const InputDecoration(labelText: 'المبلغ الشهري', prefixIcon: Icon(Icons.payments_outlined)),
              validator: requiredAmount,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'يوم الشهر', prefixIcon: Icon(Icons.calendar_month_outlined)),
              items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
              onChanged: (value) => setState(() => _day = value ?? _day),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                [
                  'المرة القادمة: ${friendlyDate(next)}',
                  if (_day > 28) 'في الأشهر الأقصر يُضاف في آخر يوم من الشهر',
                ].join('\n'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Text('الفئة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in itemCategories)
                  ChoiceChip(
                    avatar: Icon(category.icon, size: 18),
                    label: Text(category.label),
                    selected: _category == category.key,
                    onSelected: (selected) => setState(() => _category = selected ? category.key : null),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'حفظ التعديل' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

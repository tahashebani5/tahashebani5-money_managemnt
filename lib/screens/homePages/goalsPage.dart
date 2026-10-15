import 'package:flutter/material.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

// Savings goals. They only track money set aside; the balance is not changed.
class Goalspage extends StatefulWidget {
  final int account_id;
  const Goalspage({super.key, required this.account_id});

  @override
  State<Goalspage> createState() => _GoalspageState();
}

// How much is still needed per month to reach the goal by its deadline.
// null when there is no deadline, it has passed, or the goal is reached.
double? monthlyNeeded(double target, double saved, String? deadline, {DateTime? now}) {
  final end = DateTime.tryParse(deadline ?? '');
  final left = target - saved;
  if (end == null || left <= 0) return null;
  final today = now ?? DateTime.now();
  final days = DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days < 0) return null;
  final months = (days / 30.44).ceil();
  return left / (months < 1 ? 1 : months);
}

class _GoalspageState extends State<Goalspage> {
  void _reload() {
    if (mounted) setState(() {});
  }

  void _openForm([Map<String, dynamic>? goal]) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => _GoalForm(account_id: widget.account_id, goal: goal)))
        .then((_) => _reload());
  }

  Future<void> _changeSaved(Map<String, dynamic> goal, {required bool add}) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(add ? 'إضافة إلى "${goal['name']}"' : 'سحب من "${goal['name']}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(
            labelText: 'المبلغ',
            helperText: add ? null : 'المدخر حالياً ${moneyText(goal['saved'])}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
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
    if (amount == null) return;
    await DatabaseHelper().changeGoalSaved(goal['goal_id'] as int, add ? amount : -amount);
    _reload();
  }

  Future<void> _showActions(Map<String, dynamic> goal) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.add_circle_outline), title: const Text('إضافة مبلغ'),
                onTap: () => Navigator.of(context).pop('add')),
            ListTile(leading: const Icon(Icons.remove_circle_outline), title: const Text('سحب مبلغ'),
                onTap: () => Navigator.of(context).pop('withdraw')),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل الهدف'),
                onTap: () => Navigator.of(context).pop('edit')),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('حذف الهدف', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'add':
        await _changeSaved(goal, add: true);
      case 'withdraw':
        await _changeSaved(goal, add: false);
      case 'edit':
        _openForm(goal);
      case 'delete':
        final confirmed = await confirmDialog(
          context,
          title: 'حذف الهدف',
          message: 'هل تريد حذف هدف "${goal['name']}"؟ رصيد الحساب لن يتغير.',
          confirmLabel: 'حذف',
        );
        if (confirmed) {
          await DatabaseHelper().deleteGoal(goal['goal_id'] as int);
          _reload();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أهداف الادخار')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('هدف جديد'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getGoals(widget.account_id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final goals = snapshot.data!;
          if (goals.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'لا توجد أهداف بعد',
              subtitle: 'مثلاً: هاتف جديد، سفر، أو مبلغ للطوارئ. تابع كم ادخرت وكم بقي',
            );
          }
          final totalSaved = goals.fold<double>(0, (s, g) => s + (g['saved'] as num).toDouble());
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SummaryCard(
                label: 'مجموع المدخر للأهداف',
                value: moneyText(totalSaved),
                footer: Text(
                  'المبالغ المدخرة جزء من رصيدك، الأهداف للمتابعة فقط ولا تغيّر الرصيد',
                  style: TextStyle(color: onBrand.withValues(alpha: 0.85)),
                ),
              ),
              for (final goal in goals) _goalCard(goal),
            ],
          );
        },
      ),
    );
  }

  Widget _goalCard(Map<String, dynamic> goal) {
    final scheme = Theme.of(context).colorScheme;
    final target = (goal['target'] as num).toDouble();
    final saved = (goal['saved'] as num).toDouble();
    final done = saved >= target;
    final deadline = goal['deadline'] as String?;
    final perMonth = monthlyNeeded(target, saved, deadline);
    final passed = !done && deadline != null && deadline.compareTo(DatabaseHelper().formatDate(DateTime.now())) < 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActions(goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(done ? Icons.emoji_events : Icons.flag_outlined, color: done ? Colors.amber.shade700 : scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(goal['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    '${(target > 0 ? (saved / target * 100).clamp(0, 100) : 0).round()}%',
                    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: target > 0 ? (saved / target).clamp(0.0, 1.0) : 0,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text('${moneyText(saved)} من ${moneyText(target)}', style: const TextStyle(fontSize: 15)),
              if (done)
                Text('🎉 تم الوصول إلى الهدف', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold))
              else if (deadline != null)
                Text(
                  passed
                      ? 'انتهى الموعد (${friendlyDate(deadline)}) وبقي ${moneyText(target - saved)}'
                      : 'الموعد ${friendlyDate(deadline)}${perMonth == null ? '' : ' · ادخر ${moneyText(perMonth)} شهرياً'}',
                  style: TextStyle(color: passed ? scheme.error : scheme.onSurfaceVariant),
                )
              else
                Text('بقي ${moneyText(target - saved)}', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  final int account_id;
  final Map<String, dynamic>? goal;
  const _GoalForm({required this.account_id, this.goal});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  String? _deadline;
  bool _saving = false;

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _name.text = goal['name'] as String;
      _target.text = DatabaseHelper().formatMoney(goal['target']).replaceAll(',', '');
      _deadline = goal['deadline'] as String?;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_deadline ?? '') ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _deadline = DatabaseHelper().formatDate(picked));
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final values = {
      'name': _name.text.trim(),
      'target': double.parse(_target.text),
      'deadline': _deadline,
    };
    if (_isEdit) {
      await DatabaseHelper().updateGoal(widget.goal!['goal_id'] as int, values);
    } else {
      await DatabaseHelper().addGoal({
        ...values,
        'account_id': widget.account_id,
        'saved': double.tryParse(_saved.text) ?? 0.0,
        'created_date': DatabaseHelper().formatDate(DateTime.now()),
      });
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الهدف' : 'هدف جديد')),
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
                labelText: 'اسم الهدف',
                hintText: 'مثلاً: هاتف جديد',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'أدخل اسم الهدف' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'المبلغ المطلوب', prefixIcon: Icon(Icons.savings_outlined)),
              validator: requiredAmount,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _saved,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                decoration: const InputDecoration(
                  labelText: 'ادخرت منه حتى الآن (اختياري)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDeadline,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'الموعد (اختياري)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _deadline == null
                      ? null
                      : IconButton(
                          tooltip: 'إزالة',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _deadline = null),
                        ),
                ),
                child: Text(_deadline == null ? 'بدون موعد' : friendlyDate(_deadline!)),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'حفظ التعديل' : 'حفظ الهدف'),
            ),
          ],
        ),
      ),
    );
  }
}

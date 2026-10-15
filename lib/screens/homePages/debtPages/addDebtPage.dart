import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Adddebtpage extends StatefulWidget {
  final int account_id;
  const Adddebtpage({super.key, required this.account_id});

  @override
  State<Adddebtpage> createState() => _AdddebtpageState();
}

class _AdddebtpageState extends State<Adddebtpage> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _direction = DatabaseHelper.debtOwedToMe;
  String _date = DatabaseHelper().formatDate(DateTime.now());
  String? _dueDate;
  bool _countsInBalance = true;
  bool _saving = false;

  bool get _iOwe => _direction == DatabaseHelper.debtIOwe;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    await DatabaseHelper().addDebt({
      'account_id': widget.account_id,
      'person': _person.text.trim(),
      'direction': _direction,
      'amount': double.parse(_amount.text),
      'debt_date': _date,
      'due_date': _dueDate,
      'note': note.isEmpty ? null : note,
      'counts_in_balance': _countsInBalance ? 1 : 0,
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dueDate ?? '') ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _dueDate = DatabaseHelper().formatDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('دين جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: DatabaseHelper.debtOwedToMe,
                  icon: Icon(Icons.call_made),
                  label: Text('لي (أقرضتُ)'),
                ),
                ButtonSegment(
                  value: DatabaseHelper.debtIOwe,
                  icon: Icon(Icons.call_received),
                  label: Text('عليّ (اقترضتُ)'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (value) => setState(() => _direction = value.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _person,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _iOwe ? 'اقترضتُ من' : 'أقرضتُ',
                hintText: 'اسم الشخص',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'أدخل اسم الشخص' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: requiredAmount,
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await pickDate(context, initial: _date);
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التاريخ',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(friendlyDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDueDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'موعد السداد (اختياري)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _dueDate == null
                      ? null
                      : IconButton(
                          tooltip: 'إزالة',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                ),
                child: Text(_dueDate == null ? 'بدون موعد' : friendlyDate(_dueDate!)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('سجّل المبلغ في رصيد الحساب'),
              subtitle: Text(
                _countsInBalance
                    ? (_iOwe
                        ? 'استلمتُ المال: سيُضاف المبلغ إلى الرصيد الآن'
                        : 'أعطيتُ المال: سيُخصم المبلغ من الرصيد الآن')
                    : 'للتسجيل فقط (مثلاً دين قديم أو شراء بالآجل)',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              value: _countsInBalance,
              onChanged: (value) => setState(() => _countsInBalance = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الدين'),
            ),
          ],
        ),
      ),
    );
  }
}

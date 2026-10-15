import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Adddepositepage extends StatefulWidget {
  final int account_id;
  // When set, the page edits this deposit instead of adding a new one
  final Map<String, dynamic>? deposite;
  const Adddepositepage({Key? key,required this.account_id, this.deposite}): super(key: key);

  @override
  State<Adddepositepage> createState() => _AdddepositepageState();
}

class _AdddepositepageState extends State<Adddepositepage> {
  final _formKey = GlobalKey<FormState>();
  final account_balance_field = TextEditingController();
  late String _date;
  bool _saving = false;

  bool get _isEdit => widget.deposite != null;

  @override
  void initState() {
    super.initState();
    final deposite = widget.deposite;
    _date = deposite?['deposite_date'] ?? DatabaseHelper().formatDate(DateTime.now());
    if (deposite != null) {
      account_balance_field.text =
          DatabaseHelper().formatMoney(deposite['deposite_balance']).replaceAll(',', '');
    }
  }

  @override
  void dispose() {
    account_balance_field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(account_balance_field.text);
    if (_isEdit) {
      await DatabaseHelper().updateDeposite(widget.deposite!['deposites_id'], amount, _date);
    } else {
      final Map<String, dynamic> balance = {
        'account_id': widget.account_id,
        'deposite_balance': amount,
        'deposite_date': _date,
      };
      await DatabaseHelper().addDeposite(balance);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الإيداع' : 'إضافة رصيد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: account_balance_field,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(Icons.savings_outlined),
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
                child: Text(ltr(_date)),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'حفظ التعديل' : 'حفظ الإيداع'),
            ),
          ],
        ),
      ),
    );
  }
}

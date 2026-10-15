import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Adddepositepage extends StatefulWidget {
  final int account_id;
  const Adddepositepage({Key? key,required this.account_id}): super(key: key);

  @override
  State<Adddepositepage> createState() => _AdddepositepageState();
}

class _AdddepositepageState extends State<Adddepositepage> {
  final _formKey = GlobalKey<FormState>();
  final account_balance_field = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    account_balance_field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final Map<String, dynamic> balance = {
      'account_id': widget.account_id,
      'deposite_balance': double.parse(account_balance_field.text),
      'deposite_date': DatabaseHelper().formatDate(DateTime.now()),
    };
    await DatabaseHelper().addDeposite(balance);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة رصيد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: account_balance_field,
              autofocus: true,
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
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الإيداع'),
            ),
          ],
        ),
      ),
    );
  }
}

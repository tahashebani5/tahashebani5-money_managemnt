import 'package:flutter/material.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

class Createaccount extends StatefulWidget {
  const Createaccount({super.key});

  @override
  State<Createaccount> createState() => _CreateaccountState();
}

class _CreateaccountState extends State<Createaccount> {
  final _formKey = GlobalKey<FormState>();
  final account_name_field = TextEditingController();
  final account_balance_field = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    account_name_field.dispose();
    account_balance_field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final Map<String, dynamic> account = {
      'account_name': account_name_field.text.trim(),
      'account_balance': double.parse(account_balance_field.text),
    };
    await DatabaseHelper().addAccount(account);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة حساب جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: account_name_field,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم الحساب',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'أدخل اسم الحساب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: account_balance_field,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'الرصيد الافتتاحي',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) =>
                  double.tryParse(value ?? '') == null ? 'أدخل الرصيد' : null,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الحساب'),
            ),
          ],
        ),
      ),
    );
  }
}

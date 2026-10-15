import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Additem extends StatefulWidget {
  final int bill_id;
  final int account_id;
  final String date;
  Additem({Key? key, required this.bill_id,required this.account_id,required this.date});

  @override
  State<Additem> createState() => _AdditemState();
}

class _AdditemState extends State<Additem> {
  final _formKey = GlobalKey<FormState>();
  final item_name_field = TextEditingController();
  final item_price_field = TextEditingController();
  final item_count_field = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    item_name_field.dispose();
    item_price_field.dispose();
    item_count_field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.parse(item_price_field.text);
    final Map<String, dynamic> item = {
      'bill_id': widget.bill_id,
      'item_name': item_name_field.text.trim(),
      'item_price': price,
      'item_count': int.parse(item_count_field.text),
    };
    await DatabaseHelper().addItemToBill(item, widget.account_id, price);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عنصر')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: item_name_field,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم العنصر',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'أدخل اسم العنصر' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: item_count_field,
              keyboardType: TextInputType.number,
              inputFormatters: countInputFormatters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الكمية',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (value) {
                final count = int.tryParse(value ?? '');
                if (count == null || count < 1) return 'أدخل الكمية (1 على الأقل)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: item_price_field,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'السعر الإجمالي',
                helperText: 'سعر كل الكمية معاً',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: requiredAmount,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

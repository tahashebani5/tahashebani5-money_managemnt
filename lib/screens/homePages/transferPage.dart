import 'package:flutter/material.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

// Moves money from this account to another one.
class Transferpage extends StatefulWidget {
  final int account_id;
  const Transferpage({super.key, required this.account_id});

  @override
  State<Transferpage> createState() => _TransferpageState();
}

class _TransferpageState extends State<Transferpage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _accounts = DatabaseHelper().getAccounts();
  int? _toAccountId;
  String _date = DatabaseHelper().formatDate(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    await DatabaseHelper().addTransfer(
      widget.account_id,
      _toAccountId!,
      double.parse(_amount.text),
      _date,
      note.isEmpty ? null : note,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل إلى حساب آخر')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final others = snapshot.data!.where((a) => a['account_id'] != widget.account_id).toList();
          if (others.isEmpty) {
            return const EmptyState(
              icon: Icons.swap_horiz,
              title: 'لا يوجد حساب آخر',
              subtitle: 'أضف حساباً ثانياً من شاشة الحسابات لتتمكن من التحويل إليه',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: 'إلى حساب',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final account in others)
                      DropdownMenuItem(
                        value: account['account_id'] as int,
                        child: Text('${account['account_name']} · ${moneyText(account['account_balance'])}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _toAccountId = value),
                  validator: (value) => value == null ? 'اختر الحساب' : null,
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
                TextFormField(
                  controller: _note,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes),
                  ),
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
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('تحويل'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

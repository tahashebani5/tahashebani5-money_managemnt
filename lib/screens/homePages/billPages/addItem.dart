import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Additem extends StatefulWidget {
  final int bill_id;
  final int account_id;
  final String date;
  // When set, the page edits this item instead of adding a new one
  final Map<String, dynamic>? item;
  Additem({Key? key, required this.bill_id,required this.account_id,required this.date, this.item});

  @override
  State<Additem> createState() => _AdditemState();
}

class _AdditemState extends State<Additem> {
  final _formKey = GlobalKey<FormState>();
  final item_name_field = TextEditingController();
  final item_price_field = TextEditingController();
  final item_count_field = TextEditingController(text: '1');
  final _nameFocus = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  String? _category;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      item_name_field.text = item['item_name'].toString();
      item_count_field.text = item['item_count'].toString();
      _category = item['category'] as String?;
      item_price_field.text = DatabaseHelper().formatMoney(item['item_price']).replaceAll(',', '');
    }
    DatabaseHelper().getItemSuggestions(widget.account_id).then((rows) {
      if (mounted) setState(() => _suggestions = rows);
    });
  }

  @override
  void dispose() {
    item_name_field.dispose();
    item_price_field.dispose();
    item_count_field.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = item_name_field.text.trim();
    final count = int.parse(item_count_field.text);
    final price = double.parse(item_price_field.text);
    if (_isEdit) {
      await DatabaseHelper().updateItem(widget.item!['item_id'], widget.account_id, name, count, price, _category);
    } else {
      final Map<String, dynamic> item = {
        'bill_id': widget.bill_id,
        'item_name': name,
        'item_price': price,
        'item_count': count,
        'category': _category,
      };
      await DatabaseHelper().addItemToBill(item, widget.account_id, price);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  // Picking a suggestion also fills in the last count and price used for it.
  void _useSuggestion(Map<String, dynamic> suggestion) {
    item_name_field.text = suggestion['name'] as String;
    item_count_field.text = suggestion['item_count'].toString();
    item_price_field.text = DatabaseHelper().formatMoney(suggestion['item_price']).replaceAll(',', '');
    setState(() => _category = suggestion['category'] as String?);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل عنصر' : 'إضافة عنصر')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            RawAutocomplete<Map<String, dynamic>>(
              textEditingController: item_name_field,
              focusNode: _nameFocus,
              displayStringForOption: (option) => option['name'] as String,
              optionsBuilder: (value) {
                final text = value.text.trim().toLowerCase();
                if (text.isEmpty) return const [];
                return _suggestions
                    .where((s) => (s['name'] as String).toLowerCase().contains(text))
                    .take(6);
              },
              onSelected: _useSuggestion,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: !_isEdit,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم العنصر',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'أدخل اسم العنصر' : null,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final option in options)
                            ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(option['name'] as String),
                              subtitle: Text(
                                'آخر مرة: الكمية ${option['item_count']} بسعر ${moneyText(option['item_price'])}',
                              ),
                              onTap: () => onSelected(option),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                    // Tapping the selected chip again clears the category
                    onSelected: (selected) =>
                        setState(() => _category = selected ? category.key : null),
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

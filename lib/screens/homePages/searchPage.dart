import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/billPages/billPage.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

// Search every bill of the account for items by name.
class Searchpage extends StatefulWidget {
  final int account_id;
  const Searchpage({super.key, required this.account_id});

  @override
  State<Searchpage> createState() => _SearchpageState();
}

class _SearchpageState extends State<Searchpage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openBill(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => Billpage(
              account_id: widget.account_id,
              date: item['bill_date'],
              bill_id: item['bill_id'],
            ),
          ),
        )
        .then((_) {
          // The item may have been edited or deleted inside the bill
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _query.text.trim();
    final barText = Theme.of(context).appBarTheme.foregroundColor ?? scheme.onPrimary;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: barText, fontSize: 18),
          cursorColor: barText,
          decoration: InputDecoration(
            hintText: 'ابحث عن عنصر، مثلاً: خبز',
            hintStyle: TextStyle(color: barText.withValues(alpha: 0.7)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (text.isNotEmpty)
            IconButton(
              tooltip: 'مسح',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
      ),
      body: text.isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'ابحث في كل الفواتير',
              subtitle: 'اكتب اسم العنصر لترى كم مرة اشتريته وكم دفعت',
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().searchItems(widget.account_id, text),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return EmptyState(icon: Icons.search_off, title: 'لا توجد نتائج لـ "$text"');
                }
                final total = items.fold<num>(0, (sum, i) => sum + (i['item_price'] as num));
                final count = items.fold<num>(0, (sum, i) => sum + (i['item_count'] as num));
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    SummaryCard(
                      label: 'المجموع المدفوع',
                      value: moneyText(total),
                      footer: Text(
                        '${items.length} عملية شراء · الكمية الكلية $count',
                        style: TextStyle(color: onBrand.withValues(alpha: 0.85)),
                      ),
                    ),
                    for (final item in items)
                      Card(
                        child: ListTile(
                          onTap: () => _openBill(item),
                          leading: CircleAvatar(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                            child: Text(
                              '×${item['item_count']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          title: Text(item['item_name'].toString(), style: const TextStyle(fontSize: 18)),
                          subtitle: Text(friendlyDate(item['bill_date'].toString())),
                          trailing: Text(
                            moneyText(item['item_price']),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

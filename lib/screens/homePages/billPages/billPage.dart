import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:money_management/screens/homePages/billPages/addItem.dart';
import 'package:money_management/services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Billpage extends StatefulWidget {
  final int account_id;
  final String date;
  final int bill_id;
  const Billpage({
    Key? key,
    required this.account_id,
    required this.date,
    required this.bill_id,
  }) : super(key: key);

  @override
  State<Billpage> createState() => _BillpageState();
}

class _BillpageState extends State<Billpage> {
  // Own messenger so the "undo" bar stays on this page and closes with it
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<List<dynamic>> _load() {
    return Future.wait([
      DatabaseHelper().getBillById(widget.bill_id),
      DatabaseHelper().getItems(widget.bill_id),
    ]);
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف عنصر',
      message:
          'هل تريد حذف "${item['item_name']}"؟ سيتم إرجاع ${moneyText(item['item_price'])} إلى الرصيد.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;

    final price = (item['item_price'] as num).toDouble();
    await DatabaseHelper().deleteItem(
      item['item_id'],
      widget.account_id,
      widget.bill_id,
      price,
    );
    if (!mounted) return;
    setState(() {});

    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('تم حذف "${item['item_name']}"'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            await DatabaseHelper().addItemToBill(
              {
                'bill_id': widget.bill_id,
                'item_name': item['item_name'],
                'item_price': price,
                'item_count': item['item_count'],
              },
              widget.account_id,
              price,
            );
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // Opens the item form; pass [item] to edit it instead of adding a new one.
  Future<void> _openItemForm([Map<String, dynamic>? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Additem(
          bill_id: widget.bill_id,
          account_id: widget.account_id,
          date: widget.date,
          item: item,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text('فاتورة ${ltr(widget.date)}')),
        body: FutureBuilder<List<dynamic>>(
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final bill = snapshot.data![0] as Map<String, dynamic>?;
            final items = snapshot.data![1] as List<Map<String, dynamic>>;

            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                SummaryCard(
                  label: 'إجمالي الفاتورة',
                  value: moneyText(bill?['total_price']),
                  footer: Text(
                    '${items.length} عنصر',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'لا يوجد عناصر',
                    subtitle: 'اضغط على "إضافة عنصر" لتسجيل أول مشترياتك',
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                    child: Text(
                      'اضغط على العنصر لتعديله، أو اسحبه للتعديل أو الحذف',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                for (final item in items)
                  Padding(
                    key: ValueKey(item['item_id']),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Slidable(
                      endActionPane: ActionPane(
                        motion: const StretchMotion(),
                        extentRatio: 0.5,
                        children: [
                          SlidableAction(
                            borderRadius: BorderRadius.circular(16),
                            onPressed: (_) => _openItemForm(item),
                            icon: Icons.edit,
                            label: 'تعديل',
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          SlidableAction(
                            borderRadius: BorderRadius.circular(16),
                            onPressed: (_) => _deleteItem(item),
                            icon: Icons.delete,
                            label: 'حذف',
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          ),
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _openItemForm(item),
                          leading: CircleAvatar(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                            child: Text(
                              '×${item['item_count']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            item['item_name'].toString(),
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: Text('الكمية: ${item['item_count']}'),
                          trailing: Text(
                            moneyText(item['item_price']),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openItemForm(),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('إضافة عنصر'),
        ),
      ),
    );
  }
}

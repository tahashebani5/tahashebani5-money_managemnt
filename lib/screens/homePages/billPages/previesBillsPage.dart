import 'package:money_management/screens/homePages/billPages/billPage.dart';

import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';
import 'package:flutter/material.dart';


class Previesbillspage extends StatefulWidget {
  final  int account_id;
  const Previesbillspage({Key? key ,required this.account_id}): super(key: key);

  @override
  State<Previesbillspage> createState() => _PreviesbillspageState();
}

class _PreviesbillspageState extends State<Previesbillspage> {
  void _openBill(Map<String, dynamic> bill) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => Billpage(
              account_id: widget.account_id,
              date: bill['bill_date'],
              bill_id: bill['bill_id'],
            ),
          ),
        )
        .then((_) {
          // Totals may have changed inside the bill
          setState(() {});
        });
  }

  // Opens (or creates) the bill for a date the user picks.
  Future<void> _openBillForDate() async {
    final date = await pickDate(context);
    if (date == null) return;
    final billId = await DatabaseHelper().getOrCreateBill(widget.account_id, date);
    if (!mounted) return;
    _openBill({'bill_date': date, 'bill_id': billId});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBillForDate,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('فاتورة بتاريخ آخر'),
      ),
      appBar: AppBar(title: const Text('الفواتير')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getBills(widget.account_id, nonEmptyOnly: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bills = snapshot.data ?? [];
          if (bills.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'لا توجد فواتير بعد');
          }

          // Bills come newest first; group them by month ("2026-10")
          final Map<String, List<Map<String, dynamic>>> months = {};
          for (final bill in bills) {
            final date = bill['bill_date'].toString();
            final key = date.length >= 7 ? date.substring(0, 7) : date;
            months.putIfAbsent(key, () => []).add(bill);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final entry in months.entries) ...[
                SectionHeader(
                  title: monthTitle(entry.value.first['bill_date']),
                  trailing: moneyText(
                    entry.value.fold<num>(0, (sum, bill) => sum + (bill['total_price'] as num)),
                  ),
                ),
                for (final bill in entry.value)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: const Icon(Icons.receipt_long),
                      ),
                      title: Text(friendlyDate(bill['bill_date'].toString())),
                      trailing: Text(
                        moneyText(bill['total_price']),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _openBill(bill),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

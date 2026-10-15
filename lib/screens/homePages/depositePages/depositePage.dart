import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/depositePages/addDepositePage.dart';
import '../../../services/Database_Services.dart';
import '../../../widgets/commonWidgets.dart';

class Depositepage extends StatefulWidget {
  final int account_id;
  const Depositepage({Key? key, required this.account_id}) : super(key: key);

  @override
  State<Depositepage> createState() => _DepositepageState();
}

class _DepositepageState extends State<Depositepage> {
  @override
  Widget build(BuildContext context) {
    final green = Colors.green.shade600;
    return Scaffold(
      appBar: AppBar(title: const Text('الإيداعات')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getDeposites(widget.account_id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final deposites = snapshot.data ?? [];
          if (deposites.isEmpty) {
            return const EmptyState(
              icon: Icons.savings_outlined,
              title: 'لا توجد إيداعات',
              subtitle: 'اضغط على "إضافة رصيد" لتسجيل أول إيداع',
            );
          }

          // Deposits come newest first; group them by month ("2026-10")
          final Map<String, List<Map<String, dynamic>>> months = {};
          for (final deposite in deposites) {
            final date = deposite['deposite_date'].toString();
            final key = date.length >= 7 ? date.substring(0, 7) : date;
            months.putIfAbsent(key, () => []).add(deposite);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final entry in months.entries) ...[
                SectionHeader(
                  title: monthTitle(entry.value.first['deposite_date']),
                  trailing: moneyText(
                    entry.value.fold<num>(0, (sum, d) => sum + (d['deposite_balance'] as num)),
                  ),
                ),
                for (final deposite in entry.value)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: green.withValues(alpha: 0.15),
                        foregroundColor: green,
                        child: const Icon(Icons.savings_outlined),
                      ),
                      title: Text(
                        '+${moneyText(deposite['deposite_balance'])}',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: green),
                      ),
                      subtitle: Text(deposite['deposite_date'].toString()),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => Adddepositepage(account_id: widget.account_id),
                ),
              )
              .then((_) {
                setState(() {});
              });
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة رصيد'),
      ),
    );
  }
}

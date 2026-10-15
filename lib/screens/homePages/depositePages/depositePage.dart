import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  // Own messenger so the "undo" bar stays on this page and closes with it
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Opens the deposit form; pass [deposite] to edit it instead of adding one.
  void _openForm([Map<String, dynamic>? deposite]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => Adddepositepage(account_id: widget.account_id, deposite: deposite),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Future<void> _delete(Map<String, dynamic> deposite) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف إيداع',
      message: 'هل تريد حذف إيداع ${moneyText(deposite['deposite_balance'])}؟ سيتم خصمه من الرصيد.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;

    await DatabaseHelper().deleteDeposite(deposite['deposites_id']);
    if (!mounted) return;
    setState(() {});

    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('تم حذف الإيداع'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            await DatabaseHelper().addDeposite({
              'account_id': widget.account_id,
              'deposite_balance': deposite['deposite_balance'],
              'deposite_date': deposite['deposite_date'],
              'note': deposite['note'],
            });
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = Colors.green.shade600;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    'اضغط على الإيداع لتعديله، أو اسحبه للتعديل أو الحذف',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
                for (final entry in months.entries) ...[
                  SectionHeader(
                    title: monthTitle(entry.value.first['deposite_date']),
                    trailing: moneyText(
                      entry.value.fold<num>(0, (sum, d) => sum + (d['deposite_balance'] as num)),
                    ),
                  ),
                  for (final deposite in entry.value)
                    Padding(
                      key: ValueKey(deposite['deposites_id']),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Slidable(
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.5,
                          children: [
                            SlidableAction(
                              borderRadius: BorderRadius.circular(16),
                              onPressed: (_) => _openForm(deposite),
                              icon: Icons.edit,
                              label: 'تعديل',
                              backgroundColor: scheme.secondaryContainer,
                              foregroundColor: scheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 6),
                            SlidableAction(
                              borderRadius: BorderRadius.circular(16),
                              onPressed: (_) => _delete(deposite),
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
                            onTap: () => _openForm(deposite),
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
                            subtitle: Text(
                              [
                                friendlyDate(deposite['deposite_date'].toString()),
                                if ((deposite['note'] as String?)?.isNotEmpty ?? false) deposite['note'] as String,
                              ].join(' · '),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة رصيد'),
        ),
      ),
    );
  }
}

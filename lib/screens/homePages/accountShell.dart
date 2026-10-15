import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/billPages/previesBillsPage.dart';
import 'package:money_management/screens/homePages/depositePages/depositePage.dart';
import 'package:money_management/screens/homePages/homePage.dart';
import 'package:money_management/screens/homePages/statisticsPage.dart';

// One account's screens with a bottom navigation bar.
// Each tab is rebuilt when selected, so it always shows fresh numbers.
class Accountshell extends StatefulWidget {
  final int account_id;
  const Accountshell({super.key, required this.account_id});

  @override
  State<Accountshell> createState() => _AccountshellState();
}

class _AccountshellState extends State<Accountshell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final id = widget.account_id;
    return Scaffold(
      body: switch (_tab) {
        0 => Homepage(acccount_id: id),
        1 => Previesbillspage(account_id: id),
        2 => Depositepage(account_id: id),
        _ => Statisticspage(account_id: id),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'الفواتير',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'الإيداعات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'الإحصائيات',
          ),
        ],
      ),
    );
  }
}

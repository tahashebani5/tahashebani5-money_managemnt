import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/billPages/billPage.dart';
import 'package:money_management/screens/homePages/billPages/previesBillsPage.dart';
import 'package:money_management/screens/homePages/depositePages/depositePage.dart';
import '../../services/Database_Services.dart';

class Homepage extends StatefulWidget {
  final acccount_id;
  const Homepage({Key? key, required this.acccount_id}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  @override
  Widget build(BuildContext context) {
    //Future<Map<String,dynamic>?> account = DatabaseHelper().getAccount(widget.acccount_id);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(250.0),
        child: AppBar(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          title: null,
          flexibleSpace: Center(
            child: FutureBuilder(
              future: DatabaseHelper().getAccount(widget.acccount_id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Show a loader
                }

                // Check if there was an error
                if (snapshot.hasError) {
                  print('Error: ${snapshot.error}');
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.hasData) {
                  final Map<String, dynamic> account = snapshot.data!;
                  return SizedBox(
                    height: 210,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          account['account_name'] as String,
                          style: TextStyle(fontSize: 30, color: Colors.white),
                        ),
                        Text(
                          'الرصيد\n' +
                              account['account_balance'].toString() +
                              '\$',
                          style: TextStyle(fontSize: 25, color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }
                return Text('error');
              },
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 40, right: 40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (await DatabaseHelper().isTodaysBill(
                      DateTime.now(),
                      widget.acccount_id,
                    )) {
                      final Map<String, dynamic> bill = {
                        'account_id': widget.acccount_id,
                        'total_price': 0.00,
                        'bill_date': DatabaseHelper().formatDate(
                          DateTime.now(),
                        ),
                      };
                      DatabaseHelper().addBill(bill);
                    }
                    final Map<String, dynamic>? bill= await DatabaseHelper().getBill(widget.acccount_id, DatabaseHelper().formatDate(DateTime.now()));
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Billpage(
                          account_id: widget.acccount_id,
                          date: DatabaseHelper().formatDate(DateTime.now()),
                          bill_id: bill?['bill_id'],
                        ),
                      ),
                    );
                  },
                  child: Text('فاتورة اليوم', style: TextStyle(fontSize: 30)),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            Previesbillspage(account_id: widget.acccount_id),
                      ),
                    );
                  },
                  child: Text(
                    'الفواتير السابقة',
                    style: TextStyle(fontSize: 30),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            Depositepage(account_id: widget.acccount_id),
                      ),
                    );
                  },
                  child: Text(' إضافة رصيد', style: TextStyle(fontSize: 30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

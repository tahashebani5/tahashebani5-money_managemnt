import 'package:flutter/material.dart';
import 'package:money_management/screens/homePages/depositePages/addDepositePage.dart';
import '../../../services/Database_Services.dart';

class Depositepage extends StatefulWidget {
  final int account_id;
  const Depositepage({Key? key, required this.account_id}) : super(key: key);

  @override
  State<Depositepage> createState() => _DepositepageState();
}

class _DepositepageState extends State<Depositepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper().getDeposites(widget.account_id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(); // Show a loader
              }

              // Check if there was an error
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.hasData) {
                final List<Map<String, dynamic>> deposites = snapshot.data!;
                final List<Widget> rows = deposites.map((deposite) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              deposite['deposite_balance'].toString() + '\$',
                              style: TextStyle(fontSize: 20),
                            ),
                            Text(
                              deposite['deposite_date'].toString(),
                              style: TextStyle(fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                      Divider(),
                    ],
                  );
                }).toList();
                return Expanded(
                  child: SingleChildScrollView(child: Column(children: rows)),
                );
              }
              return Expanded(
                child: Center(
                  child: Text('لا يوجد إداعات', style: TextStyle(fontSize: 40)),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40, top: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>  Adddepositepage(account_id: widget.account_id),
                          ),
                        )
                        .then((_) {
                          setState(() {});
                        });
                  },
                  child: Text('إضافة رصيد', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

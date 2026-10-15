import 'package:money_management/screens/homePages/billPages/billPage.dart';

import '../../../services/Database_Services.dart';
import 'package:flutter/material.dart';


class Previesbillspage extends StatefulWidget {
  final  int account_id;
  const Previesbillspage({Key? key ,required this.account_id}): super(key: key);

  @override
  State<Previesbillspage> createState() => _PreviesbillspageState();
}

class _PreviesbillspageState extends State<Previesbillspage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().getBills(widget.account_id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Show a loader
                }
          
                // Check if there was an error
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
          
                if(snapshot.hasData){
                   final List<Map<String, dynamic>> bills = snapshot.data!;
                   final List<Widget> rows = bills.map((bill) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Billpage(
                          account_id: widget.account_id,
                          date: bill['bill_date'],
                          bill_id: bill['bill_id'],
                        ),
                      ),
                    ).then((_) {
                      // Totals may have changed inside the bill
                      setState(() {});
                    });
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20,right: 20,top: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DatabaseHelper().formatMoney(bill['total_price'])+'\$', style: TextStyle(fontSize: 20)),
                                Text(bill['bill_date'].toString(), style: TextStyle(fontSize: 20))
                              ],
                            ),
                          ),
                          Divider()
                        ],
                      ),
                    );
                   }).toList();
                  return SingleChildScrollView(
                    child: Column(
                      children: rows,
                    ),
                  );
                }
                return Expanded(child: Center(child: Text('لا يوجد عناصر',style: TextStyle(fontSize: 40),)));
          
              }
              ),
    );
  }
}
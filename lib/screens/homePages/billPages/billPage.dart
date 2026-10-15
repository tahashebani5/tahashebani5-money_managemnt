import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:money_management/screens/homePages/billPages/addItem.dart';
import 'package:money_management/services/Database_Services.dart';

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
  int account_id = 0;
  String date = '';
  int bill_id = 0;

  @override
  Widget build(BuildContext context) {
    account_id = widget.account_id;
    bill_id = widget.bill_id;
    date = widget.date;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(250.0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppBar(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            title: null,
            flexibleSpace: FutureBuilder(
              future: DatabaseHelper().getBill(account_id, date),
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
                  final Map<String, dynamic> bill = snapshot.data!;
                  return SizedBox(
                    height: 230,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            bill['bill_date'] as String,
                            style: TextStyle(fontSize: 25, color: Colors.white),
                          ),
                          Text(
                            'ألاجمالي' +
                                ': \$' +
                                DatabaseHelper().formatMoney(bill['total_price']),
                            style: TextStyle(fontSize: 25, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(child: Text('data'));
              },
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().getItems(widget.bill_id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Show a loader
                }

                // Check if there was an error
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.data!.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        'لا يوجد عناصر',
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                  );
                }
                if (snapshot.hasData) {
                  final List<Map<String, dynamic>> items = snapshot.data!;
                  final List<Widget> rows = items.map((item) {
                    return Column(
                      children: [
                        Slidable(
                          endActionPane: ActionPane(
                            motion: StretchMotion(),
                            children: [
                              SlidableAction(
                                borderRadius: BorderRadius.circular(10),
                                onPressed: (context) async {
                                  await DatabaseHelper().deleteItem(
                                    item["item_id"],
                                    account_id,
                                    bill_id,
                                    (item["item_price"] as num).toDouble(),
                                  );
                                  if (!mounted) return;
                                  setState(() {});
                                },
                                icon: Icons.delete,
                                backgroundColor: Colors.red,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 20,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DatabaseHelper().formatMoney(item['item_price']) + '\$',
                                  style: TextStyle(fontSize: 20),
                                ),
                                Text(
                                  item['item_count'].toString(),
                                  style: TextStyle(fontSize: 20),
                                ),
                                Text(
                                  item['item_name'].toString(),
                                  style: TextStyle(fontSize: 20),
                                ),
                              ],
                            ),
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
                    child: Text(
                      'لا يوجد عناصر',
                      style: TextStyle(fontSize: 40),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60, right: 60, bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => Additem(
                                bill_id: bill_id,
                                account_id: account_id,
                                date: date,
                              ),
                            ),
                          )
                          .then((_) {
                            // Result is null when the user cancels; the ids
                            // never change here, so just reload the bill.
                            setState(() {});
                          });
                    },
                    child: Text(
                      'إضافة',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

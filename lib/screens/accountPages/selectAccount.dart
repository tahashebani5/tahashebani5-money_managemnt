import 'package:flutter/material.dart';
import 'package:money_management/screens/accountPages/createAccount.dart';
import 'package:money_management/screens/homePages/homePage.dart';
import '../../services/Database_Services.dart';

class Selectaccount extends StatefulWidget {
  const Selectaccount({super.key});

  @override
  State<Selectaccount> createState() => _SelectaccountState();
}

class _SelectaccountState extends State<Selectaccount> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Center(child: Text('الحسابات', style: TextStyle(fontSize: 30))),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper().getAccounts(),
            builder: (context, snapshot) {
              // Check if the Future is still running
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(); // Show a loader
              }
      
              // Check if there was an error
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
      
              if (snapshot.hasData) {
                // Use the map() function to transform the list of maps into a list of buttons
                final List<Map<String, dynamic>> accounts = snapshot.data!;
                final List<Widget> buttons = accounts.map((account) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40,bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          print(account['account_id']);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Homepage(
                                acccount_id: account['account_id'],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          account['account_name'],
                          style: TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  );
                }).toList();
      
                // Return a Column containing all the generated buttons
                return Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 40, left: 40),
                      child: Column(
                        children: buttons,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                      ),
                    ),
                  ),
                );
              }
      
              // // Default case for no data
              return const Text('No items found.');
            },
          ),
         
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 70,
          width: 70,

          child: FloatingActionButton(
              backgroundColor: Colors.deepPurple[300],
              foregroundColor: Colors.white,
            onPressed: () async {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const Createaccount(),
                    ),
                  )
                  .then((_) {
                    setState(() {});
                  });
              // await DatabaseHelper().deleteAll();
            },
            child: Text('+', style: TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import 'package:flutter/services.dart';

class Adddepositepage extends StatefulWidget {
  final int account_id;
  const Adddepositepage({Key? key,required this.account_id}): super(key: key);

  @override
  State<Adddepositepage> createState() => _AdddepositepageState();
}

class _AdddepositepageState extends State<Adddepositepage> {
  final account_balance_field = TextEditingController();

  @override
  void dispose() {
    account_balance_field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Text("اضافة رصيد", style: TextStyle(fontSize: 30)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 30, left: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextField(
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    controller: account_balance_field,
                    decoration: const InputDecoration(labelText: 'الرصيد',border: OutlineInputBorder()),
                     textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async{
                      if(!account_balance_field.text.isEmpty){

                      final Map<String,dynamic> balance={
                        'account_id':widget.account_id,
                        'deposite_balance': double.tryParse(account_balance_field.text),
                        'deposite_date':DatabaseHelper().formatDate(DateTime.now())
                      };
                       await DatabaseHelper().addDeposite(balance );
                       if (!context.mounted) return;
                       Navigator.of(context).pop();
                    }
                  },
                  child: Text("تأكيد"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("إلغاء"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}












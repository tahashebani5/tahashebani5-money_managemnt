import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/Database_Services.dart';

class Createaccount extends StatefulWidget {
  const Createaccount({super.key});

  @override
  State<Createaccount> createState() => _CreateaccountState();
}

class _CreateaccountState extends State<Createaccount> {
  final account_name_field = TextEditingController();
  final account_balance_field = TextEditingController();

  @override
  void dispose() {
    account_name_field.dispose();
    account_balance_field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Text("اضافة حساب جديد", style: TextStyle(fontSize: 30)),
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
                    controller: account_name_field,
                    decoration: const InputDecoration(labelText: 'الاسم',border: OutlineInputBorder()),
                    textDirection: TextDirection.rtl,
                  ),
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
                      if(!account_balance_field.text.isEmpty&&!account_name_field.text.isEmpty){

                      final Map<String,dynamic> account={
                        'account_name':account_name_field.text ,
                        'account_balance': double.tryParse(account_balance_field.text)
                      };
                       await DatabaseHelper().addAccount(account);
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

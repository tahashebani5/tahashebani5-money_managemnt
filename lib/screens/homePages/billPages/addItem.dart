import 'package:flutter/material.dart';
import '../../../services/Database_Services.dart';
import 'package:flutter/services.dart';

class Additem extends StatefulWidget {
  final int bill_id;
  final int account_id;
  final String date;
  Additem({Key? key, required this.bill_id,required this.account_id,required this.date});

  @override
  State<Additem> createState() => _AdditemState();
}

class _AdditemState extends State<Additem> {
  final item_name_field = TextEditingController();

  final item_price_field = TextEditingController();

  final item_count_field = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: null,
        flexibleSpace: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Center(
            child: Text(
              'اضافة عنصر',
              style: TextStyle(color: Colors.white, fontSize: 25),
            ),
          ),
        ),
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
                    controller: item_name_field,
                    decoration: const InputDecoration(labelText: 'إسم العنصر',border: OutlineInputBorder()),
                    textDirection: TextDirection.rtl,
                  ),
                  TextField(
                    controller: item_count_field,
                    decoration: const InputDecoration(labelText: 'عدد العنصر',border: OutlineInputBorder()),
                    textDirection: TextDirection.rtl,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: item_price_field,
                    decoration: const InputDecoration(
                      labelText: 'إجمالي السعر ',border: OutlineInputBorder()
                    ),
                    textDirection: TextDirection.rtl,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 60, right: 60, bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'إلغاء',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async{
                    if(item_count_field.text.isNotEmpty&&item_name_field.text.isNotEmpty&&item_price_field.text.isNotEmpty){
                      Map<String, dynamic> item={
                        'bill_id': widget.bill_id,
                        'item_name':item_name_field.text,
                        'item_price':double.tryParse(item_price_field.text),
                        'item_count':int.tryParse(item_count_field.text)
                      };
                      if(await DatabaseHelper().updateBalance(widget.bill_id,widget.account_id, double.parse(item_price_field.text))){
                          
                        await DatabaseHelper().addItem(item);
                      }
                     final result= {'account_id':widget.account_id,'bill_id':widget.bill_id,'date':widget.date};
                      Navigator.of(context).pop(result);
                    }
                    
                  },
                  child: Text(
                    'تأكيد',
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
    );
  }
}

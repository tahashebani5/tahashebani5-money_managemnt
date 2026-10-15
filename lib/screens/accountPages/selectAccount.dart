import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:money_management/screens/accountPages/createAccount.dart';
import 'package:money_management/screens/homePages/homePage.dart';
import '../../services/Database_Services.dart';

class Selectaccount extends StatefulWidget {
  const Selectaccount({super.key});

  @override
  State<Selectaccount> createState() => _SelectaccountState();
}

class _SelectaccountState extends State<Selectaccount> {
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textDirection: TextDirection.rtl)),
    );
  }

  Future<void> _backup() async {
    try {
      final path = await DatabaseHelper().exportBackup();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: 'نسخة احتياطية - إدارة الأموال'),
      );
    } catch (e) {
      _showMessage('تعذر إنشاء النسخة الاحتياطية');
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('استعادة نسخة احتياطية', textDirection: TextDirection.rtl),
        content: Text(
          'سيتم استبدال كل البيانات الحالية بالبيانات الموجودة في النسخة المختارة. هل تريد المتابعة؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('استعادة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final restored = await DatabaseHelper().restoreBackup(await file.readAsBytes());
      if (restored) {
        _showMessage('تمت استعادة البيانات بنجاح');
        setState(() {});
      } else {
        _showMessage('هذا الملف ليس نسخة احتياطية صالحة، لم يتم تغيير أي شيء');
      }
    } catch (e) {
      _showMessage('تعذرت استعادة النسخة الاحتياطية');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Center(child: Text('الحسابات', style: TextStyle(fontSize: 30))),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'backup') _backup();
              if (value == 'restore') _restore();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('نسخ احتياطي'),
                ),
              ),
              PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('استعادة نسخة'),
                ),
              ),
            ],
          ),
        ],
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

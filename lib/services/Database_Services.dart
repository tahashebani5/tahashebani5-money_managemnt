import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }
   DatabaseHelper._internal();

    Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }
    Future<Database> _initDatabase() async {
    // Get the path to the documents directory
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'my_database.db');

    // Open the database and create   tables
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async{
        await db.execute(
          "CREATE TABLE accounts(account_id INTEGER PRIMARY KEY, account_name TEXT, account_balance REAL)",
        );
        await db.execute(
          "CREATE TABLE bills(bill_id INTEGER PRIMARY KEY,account_id INTEGER , total_price REAL,bill_date TEXT,FOREIGN KEY (account_id) REFERENCES accounts(accounts_id))",
        );
        await db.execute(
          "CREATE TABLE items(item_id INTEGER PRIMARY KEY,bill_id INTEGER,item_name TEXT , item_price REAL,item_count INTEGER,FOREIGN KEY (bill_id) REFERENCES bills(bill_id))",
        );
        await db.execute(
          "CREATE TABLE deposites(deposites_id INTEGER PRIMARY KEY,account_id INTEGER , deposite_balance REAL,deposite_date TEXT,FOREIGN KEY (account_id) REFERENCES accounts(accounts_id))",
        );
      },
    );
  }

  Future<List<Map<String,dynamic>>> getAccounts() async{
      final db = await database;
      return await db.query('accounts');
  }


    Future<Map<String,dynamic>?> getAccount(int id) async{
      final db = await database;
      
      final List<Map<String,dynamic>> account = await db.query('accounts',where: 'account_id = ?',whereArgs: [id] );
      if (account.isNotEmpty){
        
        return account.first;
      }else{
        return null;
      }
  }


  Future<bool> isTableEmpty(String tableName) async {
  final db = await database;
  final result = await db.query(tableName, limit: 1);
  return result.isEmpty;
}
Future<int> addAccount(Map<String, dynamic> account) async {
  final db = await database;
  return await db.insert(
    'accounts', // The name of your table
    account,    // The data to insert
    conflictAlgorithm: ConflictAlgorithm.replace, // Optional but recommended
  );
}
Future<void> deleteAll() async {
  final db = await database; // Get the database instance
  await db.delete(
    'accounts', // The table name
    where: '1 = ?', // The WHERE clause to filter rows
    whereArgs: [1], // The arguments for the WHERE clause
  );
    await db.delete(
    'bills', // The table name
    where: '1 = ?', // The WHERE clause to filter rows
    whereArgs: [1], // The arguments for the WHERE clause
  );
      await db.delete(
    'items', // The table name
    where: '1 = ?', // The WHERE clause to filter rows
    whereArgs: [1], // The arguments for the WHERE clause
  );
}

  Future<bool> isTodaysBill(DateTime date,int account_id) async {


  final db = await database;
  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  final result = await db.query("bills", where: 'account_id = ? AND bill_date LIKE ?',whereArgs: [account_id,formattedDate]);
  return result.isEmpty;
}
Future<int> addBill(Map<String, dynamic> bill) async {
  final db = await database;
  return await db.insert(
    'bills', // The name of your table
    bill,    // The data to insert
    conflictAlgorithm: ConflictAlgorithm.replace, // Optional but recommended
  );
}
    Future<Map<String,dynamic>?> getBill(int id,String date) async{
      final db = await database;
      final List<Map<String,dynamic>> bill = await db.query('bills',where: 'account_id = ? AND bill_date = ?',whereArgs: [id,date] );
      if (bill.isNotEmpty){
        return bill.first;
      }else{
        return null;
      }
  }
    Future<List<Map<String,dynamic>>> getBills(int account_id) async{
      final db = await database;
      return await db.query('bills' ,where: 'account_id = ?',whereArgs: [account_id]);
  }

      Future<Map<String,dynamic>?> getBillById(int id) async{
      final db = await database;
      final List<Map<String,dynamic>> bill = await db.query('bills',where: 'bill_id = ? ',whereArgs: [id] );
      if (bill.isNotEmpty){
        return bill.first;
      }else{
        return null;
      }
  }
  String formatDate(DateTime date){
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      return formattedDate;
  }

  Future<int> addItem(Map<String, dynamic> item) async {
  final db = await database;
  return await db.insert(
    'items', // The name of your table
    item,    // The data to insert
    conflictAlgorithm: ConflictAlgorithm.replace, // Optional but recommended
  );
}
  Future<List<Map<String,dynamic>>> getItems(int id) async{
      final db = await database;
      return await db.query('items',where: 'bill_id = ?',whereArgs: [id]);
  }
  Future<bool> updateBalance(int bill_id,int account_id,double price) async{
      final db = await database;
      Map<String,dynamic>? bill = await getBillById(bill_id);
      Map<String,dynamic>? account = await getAccount(account_id);
      if(bill ==null||account==null){
        return false;
      }
      double newBill =  bill['total_price']+price;
      double newAccount =  account["account_balance"]-price ;
      db.update(
    'bills',
    {
      'total_price': newBill,
    },
    where: 'bill_id = ?',
    whereArgs: [bill_id],
  );
  db.update(
    'accounts',
    {
      'account_balance': newAccount,
    },
    where: 'account_id = ?',
    whereArgs: [account_id],
  );
  return true;
  }
  
    Future<List<Map<String,dynamic>>> getDeposites(int account_id) async{
      final db = await database;
      return await db.query('deposites',where: 'account_id = ?',whereArgs: [account_id]);
  }

    Future<int> addDeposite(Map<String, dynamic> deposite) async {
  final db = await database;
  return await db.insert(
    'deposites', // The name of your table
    deposite,    // The data to insert
    conflictAlgorithm: ConflictAlgorithm.replace, // Optional but recommended
  );
}
  Future<bool> updateBalanceAcc(int account_id,double balance) async{
      final db = await database;
      Map<String,dynamic>? account = await getAccount(account_id);
      if(account==null){
        return false;
      }
      double newAccount =  account["account_balance"]+balance ;
  db.update(
    'accounts',
    {
      'account_balance': newAccount,
    },
    where: 'account_id = ?',
    whereArgs: [account_id],
  );
  return true;
  }
}
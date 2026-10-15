import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const List<String> _requiredTables = ['accounts', 'bills', 'items', 'deposites'];

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

  Future<String> _databaseFilePath() async {
    final databasePath = await getDatabasesPath();
    return join(databasePath, 'my_database.db');
  }

  // Closes the open connection so the database file on disk is complete.
  // The next call to `database` reopens it.
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

    Future<Database> _initDatabase() async {
    final path = await _databaseFilePath();

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
  final formattedDate = DateFormat('yyyy-MM-dd', 'en_US').format(date);
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
      return await db.query('bills' ,where: 'account_id = ?',whereArgs: [account_id], orderBy: 'bill_date DESC, bill_id DESC');
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
      final formattedDate = DateFormat('yyyy-MM-dd', 'en_US').format(date);
      return formattedDate;
  }

  // Rounds to 2 decimals for display, e.g. 12.300000000001 -> 12.3
  String formatMoney(num? value){
      return NumberFormat('#,##0.##', 'en_US').format(value ?? 0);
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
  // Adds the item, raises the bill total and lowers the account balance
  // together: either all three are saved or none of them.
  Future<void> addItemToBill(Map<String, dynamic> item,int account_id,double price) async{
      final db = await database;
      await db.transaction((txn) async {
        await txn.insert('items', item);
        await txn.rawUpdate(
          'UPDATE bills SET total_price = ROUND(total_price + ?, 2) WHERE bill_id = ?',
          [price, item['bill_id']],
        );
        await txn.rawUpdate(
          'UPDATE accounts SET account_balance = ROUND(account_balance - ?, 2) WHERE account_id = ?',
          [price, account_id],
        );
      });
  }

    Future<List<Map<String,dynamic>>> getDeposites(int account_id) async{
      final db = await database;
      return await db.query('deposites',where: 'account_id = ?',whereArgs: [account_id], orderBy: 'deposite_date DESC, deposites_id DESC');
  }

  // Totals spent (bills) and deposited during the current month.
  Future<Map<String, double>> getMonthSummary(int account_id) async {
      final db = await database;
      final month = '${DateFormat('yyyy-MM', 'en_US').format(DateTime.now())}%';
      final spent = await db.rawQuery(
        'SELECT COALESCE(SUM(total_price), 0) AS total FROM bills WHERE account_id = ? AND bill_date LIKE ?',
        [account_id, month],
      );
      final deposited = await db.rawQuery(
        'SELECT COALESCE(SUM(deposite_balance), 0) AS total FROM deposites WHERE account_id = ? AND deposite_date LIKE ?',
        [account_id, month],
      );
      return {
        'spent': (spent.first['total'] as num).toDouble(),
        'deposited': (deposited.first['total'] as num).toDouble(),
      };
  }

  // Latest non-empty bills and deposits together, newest first.
  Future<List<Map<String, dynamic>>> getRecentActivity(int account_id, {int limit = 5}) async {
      final db = await database;
      return await db.rawQuery(
        "SELECT 'bill' AS type, bill_id AS id, bill_date AS date, total_price AS amount "
        "FROM bills WHERE account_id = ? AND total_price != 0 "
        "UNION ALL "
        "SELECT 'deposite' AS type, deposites_id AS id, deposite_date AS date, deposite_balance AS amount "
        "FROM deposites WHERE account_id = ? "
        "ORDER BY date DESC, id DESC LIMIT ?",
        [account_id, account_id, limit],
      );
  }

  // Saves the deposit and raises the account balance together.
  Future<void> addDeposite(Map<String, dynamic> deposite) async {
  final db = await database;
  await db.transaction((txn) async {
    await txn.insert('deposites', deposite);
    await txn.rawUpdate(
      'UPDATE accounts SET account_balance = ROUND(account_balance + ?, 2) WHERE account_id = ?',
      [deposite['deposite_balance'], deposite['account_id']],
    );
  });
}

  // Removes the item and gives its price back to the bill and the account,
  // all in one transaction.
  Future<void> deleteItem(int item_id,int account_id,int bill_id,double price)async{
      final db = await database;
      await db.transaction((txn) async {
        final deleted = await txn.delete("items",where: "item_id = ?",whereArgs: [item_id]);
        if (deleted < 1) {
          return;
        }
        await txn.rawUpdate(
          'UPDATE bills SET total_price = ROUND(total_price - ?, 2) WHERE bill_id = ?',
          [price, bill_id],
        );
        await txn.rawUpdate(
          'UPDATE accounts SET account_balance = ROUND(account_balance + ?, 2) WHERE account_id = ?',
          [price, account_id],
        );
      });
  }

  // Copies the database to a temporary file named with today's date and
  // returns its path, ready to be shared.
  Future<String> exportBackup() async {
      await closeDatabase();
      final source = File(await _databaseFilePath());
      final tempDir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd_HH-mm', 'en_US').format(DateTime.now());
      final backupPath = join(tempDir.path, 'money_backup_$stamp.db');
      await source.copy(backupPath);
      return backupPath;
  }

  // Replaces the current data with a backup file. The file is checked first,
  // and the current database is kept as my_database_before_restore.db.
  // Returns false (and changes nothing) if the file is not a valid backup.
  Future<bool> restoreBackup(Uint8List bytes) async {
      final tempDir = await getTemporaryDirectory();
      final candidate = File(join(tempDir.path, 'restore_candidate.db'));
      await candidate.writeAsBytes(bytes, flush: true);

      if (!await _isValidBackup(candidate.path)) {
        await candidate.delete();
        return false;
      }

      await closeDatabase();
      final path = await _databaseFilePath();
      final current = File(path);
      if (await current.exists()) {
        await current.copy(join(dirname(path), 'my_database_before_restore.db'));
      }
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final leftover = File('$path$suffix');
        if (await leftover.exists()) {
          await leftover.delete();
        }
      }
      await candidate.copy(path);
      await candidate.delete();
      return true;
  }

  Future<bool> _isValidBackup(String path) async {
      Database? db;
      try {
        db = await openDatabase(path, readOnly: true, singleInstance: false);
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
        final names = tables.map((t) => t['name']).toSet();
        return _requiredTables.every(names.contains);
      } catch (_) {
        return false;
      } finally {
        await db?.close();
      }
  }
}
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

  // Changes an item. The bill total and the account balance move by the
  // difference between the new and the old price, in one transaction.
  Future<void> updateItem(int item_id,int account_id,String name,int count,double price) async{
      final db = await database;
      await db.transaction((txn) async {
        final rows = await txn.query('items', where: 'item_id = ?', whereArgs: [item_id]);
        if (rows.isEmpty) {
          return;
        }
        final oldPrice = (rows.first['item_price'] as num).toDouble();
        final diff = price - oldPrice;
        await txn.update(
          'items',
          {'item_name': name, 'item_count': count, 'item_price': price},
          where: 'item_id = ?',
          whereArgs: [item_id],
        );
        await txn.rawUpdate(
          'UPDATE bills SET total_price = ROUND(total_price + ?, 2) WHERE bill_id = ?',
          [diff, rows.first['bill_id']],
        );
        await txn.rawUpdate(
          'UPDATE accounts SET account_balance = ROUND(account_balance - ?, 2) WHERE account_id = ?',
          [diff, account_id],
        );
      });
  }

  // Changes a deposit's amount/date and moves the account balance by the difference.
  Future<void> updateDeposite(int deposites_id,double amount,String date) async{
      final db = await database;
      await db.transaction((txn) async {
        final rows = await txn.query('deposites', where: 'deposites_id = ?', whereArgs: [deposites_id]);
        if (rows.isEmpty) {
          return;
        }
        final diff = amount - (rows.first['deposite_balance'] as num).toDouble();
        await txn.update(
          'deposites',
          {'deposite_balance': amount, 'deposite_date': date},
          where: 'deposites_id = ?',
          whereArgs: [deposites_id],
        );
        await txn.rawUpdate(
          'UPDATE accounts SET account_balance = ROUND(account_balance + ?, 2) WHERE account_id = ?',
          [diff, rows.first['account_id']],
        );
      });
  }

  // Removes a deposit and takes its amount back out of the account balance.
  Future<void> deleteDeposite(int deposites_id) async{
      final db = await database;
      await db.transaction((txn) async {
        final rows = await txn.query('deposites', where: 'deposites_id = ?', whereArgs: [deposites_id]);
        if (rows.isEmpty) {
          return;
        }
        await txn.delete('deposites', where: 'deposites_id = ?', whereArgs: [deposites_id]);
        await txn.rawUpdate(
          'UPDATE accounts SET account_balance = ROUND(account_balance - ?, 2) WHERE account_id = ?',
          [rows.first['deposite_balance'], rows.first['account_id']],
        );
      });
  }

  // Returns the id of the account's bill for [date] ("yyyy-MM-dd"),
  // creating an empty bill if there is none yet.
  Future<int> getOrCreateBill(int account_id,String date) async{
      final db = await database;
      return await db.transaction((txn) async {
        final rows = await txn.query(
          'bills',
          columns: ['bill_id'],
          where: 'account_id = ? AND bill_date = ?',
          whereArgs: [account_id, date],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          return rows.first['bill_id'] as int;
        }
        return await txn.insert('bills', {'account_id': account_id, 'total_price': 0.0, 'bill_date': date});
      });
  }

  // Spent and deposited per month for the last [months] months (oldest first),
  // e.g. [{'month': '2026-10', 'spent': 12.0, 'deposited': 500.0}, ...]
  Future<List<Map<String, dynamic>>> getMonthlyTotals(int account_id, {int months = 6}) async {
      final db = await database;
      final now = DateTime.now();
      final keys = [
        for (var i = months - 1; i >= 0; i--)
          DateFormat('yyyy-MM', 'en_US').format(DateTime(now.year, now.month - i)),
      ];
      final from = '${keys.first}-01';
      final spent = await db.rawQuery(
        'SELECT substr(bill_date, 1, 7) AS month, SUM(total_price) AS total FROM bills '
        'WHERE account_id = ? AND bill_date >= ? GROUP BY month',
        [account_id, from],
      );
      final deposited = await db.rawQuery(
        'SELECT substr(deposite_date, 1, 7) AS month, SUM(deposite_balance) AS total FROM deposites '
        'WHERE account_id = ? AND deposite_date >= ? GROUP BY month',
        [account_id, from],
      );
      double totalFor(List<Map<String, Object?>> rows, String month) {
        final row = rows.where((r) => r['month'] == month);
        return row.isEmpty ? 0 : (row.first['total'] as num).toDouble();
      }
      return [
        for (final month in keys)
          {'month': month, 'spent': totalFor(spent, month), 'deposited': totalFor(deposited, month)},
      ];
  }

  // Items the account spent the most on, all time.
  Future<List<Map<String, dynamic>>> getTopItems(int account_id, {int limit = 5}) async {
      final db = await database;
      return await db.rawQuery(
        'SELECT TRIM(item_name) AS name, SUM(item_price) AS total, SUM(item_count) AS count '
        'FROM items JOIN bills ON items.bill_id = bills.bill_id '
        'WHERE bills.account_id = ? GROUP BY TRIM(item_name) ORDER BY total DESC LIMIT ?',
        [account_id, limit],
      );
  }

  // Items whose name contains [query], newest first, with their bill date.
  Future<List<Map<String, dynamic>>> searchItems(int account_id, String query) async {
      final db = await database;
      return await db.rawQuery(
        'SELECT items.*, bills.bill_date FROM items JOIN bills ON items.bill_id = bills.bill_id '
        'WHERE bills.account_id = ? AND instr(lower(items.item_name), lower(?)) > 0 '
        'ORDER BY bills.bill_date DESC, items.item_id DESC',
        [account_id, query.trim()],
      );
  }

  // Previously used item names with their latest count and price, newest first.
  Future<List<Map<String, dynamic>>> getItemSuggestions(int account_id) async {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT TRIM(item_name) AS name, item_count, item_price FROM items '
        'JOIN bills ON items.bill_id = bills.bill_id WHERE bills.account_id = ? '
        'ORDER BY bills.bill_date DESC, items.item_id DESC LIMIT 1000',
        [account_id],
      );
      final seen = <String>{};
      return [
        for (final row in rows)
          if (seen.add(row['name'] as String)) row,
      ];
  }

  // Deletes the account with all its bills, items and deposits.
  // A copy of the whole database is kept first as my_database_before_delete.db.
  Future<void> deleteAccount(int account_id) async {
      await _saveSafetyCopy('my_database_before_delete.db');
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('items', where: 'bill_id IN (SELECT bill_id FROM bills WHERE account_id = ?)', whereArgs: [account_id]);
        await txn.delete('bills', where: 'account_id = ?', whereArgs: [account_id]);
        await txn.delete('deposites', where: 'account_id = ?', whereArgs: [account_id]);
        await txn.delete('accounts', where: 'account_id = ?', whereArgs: [account_id]);
      });
  }

  Future<void> _saveSafetyCopy(String fileName) async {
      await closeDatabase();
      final path = await _databaseFilePath();
      final current = File(path);
      if (await current.exists()) {
        await current.copy(join(dirname(path), fileName));
      }
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

      await _saveSafetyCopy('my_database_before_restore.db');
      final path = await _databaseFilePath();
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
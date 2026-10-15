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

  // Version history:
  // 1 - accounts, bills, items, deposites
  // 2 - items.category, deposites.note, accounts.monthly_budget,
  //     transfers and settings tables (old rows are kept, new columns empty)
  static const int _dbVersion = 2;

    Future<Database> _initDatabase() async {
    final path = await _databaseFilePath();
    await _copyBeforeUpgrade(path);

    // Open the database and create   tables
    return await openDatabase(
      path,
      version: _dbVersion,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
      },
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
        await _upgradeToV2(db);
      },
    );
  }

  // Keeps a copy of the file before an older database is upgraded,
  // e.g. my_database_before_v2.db. Never overwrites an existing copy.
  Future<void> _copyBeforeUpgrade(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final probe = await openDatabase(path, readOnly: true, singleInstance: false);
    final version = await probe.getVersion();
    await probe.close();
    if (version > 0 && version < _dbVersion) {
      final copy = File(join(dirname(path), 'my_database_before_v$_dbVersion.db'));
      if (!await copy.exists()) {
        await file.copy(copy.path);
      }
    }
  }

  // Only adds columns and tables; existing rows are never changed.
  Future<void> _upgradeToV2(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'items', 'category', 'TEXT');
    await _addColumnIfMissing(db, 'deposites', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'accounts', 'monthly_budget', 'REAL');
    await db.execute(
      'CREATE TABLE IF NOT EXISTS transfers(transfer_id INTEGER PRIMARY KEY, from_account_id INTEGER, '
      'to_account_id INTEGER, amount REAL, transfer_date TEXT, note TEXT)',
    );
    await db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)');
  }

  Future<void> _addColumnIfMissing(DatabaseExecutor db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((c) => c['name'] == column)) {
      return;
    }
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // null removes the budget.
  Future<void> setMonthlyBudget(int account_id, double? budget) async {
    final db = await database;
    await db.update('accounts', {'monthly_budget': budget}, where: 'account_id = ?', whereArgs: [account_id]);
  }

  // Moves money between two accounts: one transfer row, both balances, one transaction.
  Future<void> addTransfer(int from_account_id, int to_account_id, double amount, String date, String? note) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transfers', {
        'from_account_id': from_account_id,
        'to_account_id': to_account_id,
        'amount': amount,
        'transfer_date': date,
        'note': note,
      });
      await txn.rawUpdate(
        'UPDATE accounts SET account_balance = ROUND(account_balance - ?, 2) WHERE account_id = ?',
        [amount, from_account_id],
      );
      await txn.rawUpdate(
        'UPDATE accounts SET account_balance = ROUND(account_balance + ?, 2) WHERE account_id = ?',
        [amount, to_account_id],
      );
    });
  }

  // Removes a transfer and puts both balances back.
  Future<void> deleteTransfer(int transfer_id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('transfers', where: 'transfer_id = ?', whereArgs: [transfer_id]);
      if (rows.isEmpty) {
        return;
      }
      final t = rows.first;
      await txn.delete('transfers', where: 'transfer_id = ?', whereArgs: [transfer_id]);
      await txn.rawUpdate(
        'UPDATE accounts SET account_balance = ROUND(account_balance + ?, 2) WHERE account_id = ?',
        [t['amount'], t['from_account_id']],
      );
      await txn.rawUpdate(
        'UPDATE accounts SET account_balance = ROUND(account_balance - ?, 2) WHERE account_id = ?',
        [t['amount'], t['to_account_id']],
      );
    });
  }

  // Spending per category for the last [months] months:
  // [{'month': '2026-10', 'category': 'food', 'total': 40.0}, ...]
  // Items without a category have category ''.
  Future<List<Map<String, dynamic>>> getCategoryTotals(int account_id, {int months = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final from = '${DateFormat('yyyy-MM', 'en_US').format(DateTime(now.year, now.month - months + 1))}-01';
    return await db.rawQuery(
      "SELECT substr(bills.bill_date, 1, 7) AS month, COALESCE(items.category, '') AS category, "
      'SUM(items.item_price) AS total FROM items JOIN bills ON items.bill_id = bills.bill_id '
      'WHERE bills.account_id = ? AND bills.bill_date >= ? GROUP BY month, category ORDER BY total DESC',
      [account_id, from],
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
    // nonEmptyOnly hides bills that were opened but never got an item.
    Future<List<Map<String,dynamic>>> getBills(int account_id, {bool nonEmptyOnly = false}) async{
      final db = await database;
      final empty = nonEmptyOnly
          ? ' AND (total_price != 0 OR EXISTS (SELECT 1 FROM items WHERE items.bill_id = bills.bill_id))'
          : '';
      return await db.query('bills' ,where: 'account_id = ?$empty',whereArgs: [account_id], orderBy: 'bill_date DESC, bill_id DESC');
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

  // Latest non-empty bills, deposits and transfers together, newest first.
  // type is 'bill', 'deposite', 'transfer_out' or 'transfer_in'; for transfers
  // other_account is the name of the account on the other side.
  Future<List<Map<String, dynamic>>> getRecentActivity(int account_id, {int limit = 5}) async {
      final db = await database;
      return await db.rawQuery(
        "SELECT 'bill' AS type, bill_id AS id, bill_date AS date, total_price AS amount, "
        "NULL AS note, NULL AS other_account "
        "FROM bills WHERE account_id = ? AND total_price != 0 "
        "UNION ALL "
        "SELECT 'deposite' AS type, deposites_id AS id, deposite_date AS date, deposite_balance AS amount, "
        "note, NULL AS other_account "
        "FROM deposites WHERE account_id = ? "
        "UNION ALL "
        "SELECT 'transfer_out' AS type, transfer_id AS id, transfer_date AS date, amount, note, "
        "(SELECT account_name FROM accounts WHERE account_id = to_account_id) AS other_account "
        "FROM transfers WHERE from_account_id = ? "
        "UNION ALL "
        "SELECT 'transfer_in' AS type, transfer_id AS id, transfer_date AS date, amount, note, "
        "(SELECT account_name FROM accounts WHERE account_id = from_account_id) AS other_account "
        "FROM transfers WHERE to_account_id = ? "
        "ORDER BY date DESC, id DESC LIMIT ?",
        [account_id, account_id, account_id, account_id, limit],
      );
  }

  // Budget for the account and how much it has spent this month.
  Future<Map<String, double?>> getBudgetStatus(int account_id) async {
      final account = await getAccount(account_id);
      final summary = await getMonthSummary(account_id);
      return {
        'budget': (account?['monthly_budget'] as num?)?.toDouble(),
        'spent': summary['spent'],
      };
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
  Future<void> updateItem(int item_id,int account_id,String name,int count,double price,String? category) async{
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
          {'item_name': name, 'item_count': count, 'item_price': price, 'category': category},
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
  Future<void> updateDeposite(int deposites_id,double amount,String date,String? note) async{
      final db = await database;
      await db.transaction((txn) async {
        final rows = await txn.query('deposites', where: 'deposites_id = ?', whereArgs: [deposites_id]);
        if (rows.isEmpty) {
          return;
        }
        final diff = amount - (rows.first['deposite_balance'] as num).toDouble();
        await txn.update(
          'deposites',
          {'deposite_balance': amount, 'deposite_date': date, 'note': note},
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
        'SELECT TRIM(item_name) AS name, item_count, item_price, category FROM items '
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
        await txn.delete('transfers', where: 'from_account_id = ? OR to_account_id = ?', whereArgs: [account_id, account_id]);
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
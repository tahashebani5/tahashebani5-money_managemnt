// Runs DatabaseHelper against a real SQLite database (via sqflite_common_ffi)
// to check the money calculations and the upgrade of old databases.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_management/services/Database_Services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<String> _dbPath() async => join(await getDatabasesPath(), 'my_database.db');

Future<void> _freshStart() async {
  await DatabaseHelper().closeDatabase();
  final dir = Directory(await getDatabasesPath());
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
}

Future<double> _balance(int accountId) async =>
    ((await DatabaseHelper().getAccount(accountId))!['account_balance'] as num).toDouble();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(_freshStart);
  tearDownAll(() => DatabaseHelper().closeDatabase());

  test('a version 1 database is upgraded to the latest version without changing old rows', () async {
    // The schema exactly as the first version of the app created it
    final old = await openDatabase(await _dbPath(), version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE accounts(account_id INTEGER PRIMARY KEY, account_name TEXT, account_balance REAL)');
      await db.execute('CREATE TABLE bills(bill_id INTEGER PRIMARY KEY,account_id INTEGER , total_price REAL,bill_date TEXT)');
      await db.execute('CREATE TABLE items(item_id INTEGER PRIMARY KEY,bill_id INTEGER,item_name TEXT , item_price REAL,item_count INTEGER)');
      await db.execute('CREATE TABLE deposites(deposites_id INTEGER PRIMARY KEY,account_id INTEGER , deposite_balance REAL,deposite_date TEXT)');
    });
    await old.insert('accounts', {'account_id': 1, 'account_name': 'taha', 'account_balance': 13109.0});
    await old.insert('bills', {'bill_id': 1, 'account_id': 1, 'total_price': 12.0, 'bill_date': '2026-10-15'});
    await old.insert('items', {'item_id': 1, 'bill_id': 1, 'item_name': 'bread', 'item_price': 12.0, 'item_count': 1});
    await old.insert('deposites', {'deposites_id': 1, 'account_id': 1, 'deposite_balance': 12121.0, 'deposite_date': '2026-10-15'});
    await old.close();

    final db = await DatabaseHelper().database;
    expect(await db.getVersion(), 3);
    expect(await _balance(1), 13109.0);
    expect((await DatabaseHelper().getItems(1)).single['item_name'], 'bread');
    expect((await DatabaseHelper().getDeposites(1)).single['deposite_balance'], 12121.0);
    // New tables exist and old rows got empty new columns
    expect(await DatabaseHelper().getDebts(1), isEmpty);
    expect((await DatabaseHelper().getItems(1)).single['category'], isNull);
    // The old file was kept before upgrading
    expect(await File(join(await getDatabasesPath(), 'my_database_before_v3.db')).exists(), isTrue);
  });

  test('items, deposits and transfers keep balances consistent', () async {
    final a = await DatabaseHelper().addAccount({'account_name': 'a', 'account_balance': 1000.0});
    final b = await DatabaseHelper().addAccount({'account_name': 'b', 'account_balance': 0.0});
    final bill = await DatabaseHelper().getOrCreateBill(a, '2026-10-15');

    await DatabaseHelper().addItemToBill({'bill_id': bill, 'item_name': 'x', 'item_price': 12.3, 'item_count': 1}, a, 12.3);
    expect(await _balance(a), 987.7);
    final item = (await DatabaseHelper().getItems(bill)).single;
    await DatabaseHelper().updateItem(item['item_id'], a, 'x', 2, 20, null);
    expect(await _balance(a), 980.0);
    expect((await DatabaseHelper().getBillById(bill))!['total_price'], 20.0);
    await DatabaseHelper().deleteItem(item['item_id'], a, bill, 20);
    expect(await _balance(a), 1000.0);

    await DatabaseHelper().addDeposite({'account_id': a, 'deposite_balance': 50.0, 'deposite_date': '2026-10-15'});
    expect(await _balance(a), 1050.0);

    await DatabaseHelper().addTransfer(a, b, 100, '2026-10-15', null);
    expect(await _balance(a), 950.0);
    expect(await _balance(b), 100.0);
  });

  test('recurring expenses: catch up missed months, adjust short months, never add twice', () async {
    final db = DatabaseHelper();
    final a = await db.addAccount({'account_name': 'a', 'account_balance': 1000.0});
    await db.addRecurring({
      'account_id': a, 'name': 'rent', 'amount': 100.0, 'category': 'home',
      'day_of_month': 31, 'next_date': '2026-01-31', 'active': 1,
    });

    // Opened on 20 April: January 31, February 28, March 31 are due
    final added = await db.processDueRecurring(now: DateTime(2026, 4, 20));
    expect(added, ['rent', 'rent', 'rent']);
    expect(await _balance(a), 700.0);
    final bills = await db.getBills(a);
    expect(bills.map((b) => b['bill_date']), ['2026-03-31', '2026-02-28', '2026-01-31']);
    expect((await db.getItems(bills.first['bill_id'] as int)).single['category'], 'home');
    expect((await db.getRecurring(a)).single['next_date'], '2026-04-30');

    // Opening again the same day adds nothing
    expect(await db.processDueRecurring(now: DateTime(2026, 4, 20)), isEmpty);
    expect(await _balance(a), 700.0);

    // Paused items are skipped
    final id = (await db.getRecurring(a)).single['recurring_id'] as int;
    await db.updateRecurring(id, {'active': 0});
    expect(await db.processDueRecurring(now: DateTime(2026, 6, 1)), isEmpty);
    expect(await _balance(a), 700.0);
  });

  test('first recurring date is this month if the day has not passed', () {
    final db = DatabaseHelper();
    expect(db.firstRecurringDate(25, now: DateTime(2026, 10, 15)), '2026-10-25');
    expect(db.firstRecurringDate(15, now: DateTime(2026, 10, 15)), '2026-10-15');
    expect(db.firstRecurringDate(5, now: DateTime(2026, 10, 15)), '2026-11-05');
    expect(db.firstRecurringDate(31, now: DateTime(2026, 2, 10)), '2026-02-28');
    expect(db.firstRecurringDate(1, now: DateTime(2026, 12, 20)), '2027-01-01');
  });

  test('debts: lending, repayments and deleting move the balance correctly', () async {
    final a = await DatabaseHelper().addAccount({'account_name': 'a', 'account_balance': 1000.0});

    // Lent 200 (counts in balance): balance goes down now
    await DatabaseHelper().addDebt({
      'account_id': a, 'person': 'Ali', 'direction': DatabaseHelper.debtOwedToMe,
      'amount': 200.0, 'debt_date': '2026-10-15', 'counts_in_balance': 1,
    });
    expect(await _balance(a), 800.0);
    final lent = (await DatabaseHelper().getDebts(a)).single;

    await DatabaseHelper().addDebtPayment(lent['debt_id'], 50, '2026-10-16');
    expect(await _balance(a), 850.0);
    expect((await DatabaseHelper().getDebtTotals(a))[DatabaseHelper.debtOwedToMe], 150.0);

    final payment = (await DatabaseHelper().getDebtPayments(lent['debt_id'])).single;
    await DatabaseHelper().deleteDebtPayment(payment['payment_id']);
    expect(await _balance(a), 800.0);

    await DatabaseHelper().addDebtPayment(lent['debt_id'], 200, '2026-10-17');
    expect(await _balance(a), 1000.0);
    expect((await DatabaseHelper().getDebts(a)).single['settled'], 1);

    await DatabaseHelper().deleteDebt(lent['debt_id']);
    expect(await _balance(a), 1000.0);
    expect(await DatabaseHelper().getDebts(a), isEmpty);

    // Bought on credit 300 (does not count now); paying 100 takes it out
    await DatabaseHelper().addDebt({
      'account_id': a, 'person': 'Shop', 'direction': DatabaseHelper.debtIOwe,
      'amount': 300.0, 'debt_date': '2026-10-15', 'counts_in_balance': 0,
    });
    expect(await _balance(a), 1000.0);
    final owe = (await DatabaseHelper().getDebts(a)).single;
    await DatabaseHelper().addDebtPayment(owe['debt_id'], 100, '2026-10-16');
    expect(await _balance(a), 900.0);
    expect((await DatabaseHelper().getDebtTotals(a))[DatabaseHelper.debtIOwe], 200.0);
    await DatabaseHelper().deleteDebt(owe['debt_id']);
    expect(await _balance(a), 1000.0);

    // Borrowed 500 (counts): balance goes up, deleting undoes it
    await DatabaseHelper().addDebt({
      'account_id': a, 'person': 'Bank', 'direction': DatabaseHelper.debtIOwe,
      'amount': 500.0, 'debt_date': '2026-10-15', 'counts_in_balance': 1,
    });
    expect(await _balance(a), 1500.0);
    await DatabaseHelper().deleteDebt((await DatabaseHelper().getDebts(a)).single['debt_id']);
    expect(await _balance(a), 1000.0);
  });
}

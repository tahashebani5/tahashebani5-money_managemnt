import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_management/main.dart';
import 'package:money_management/screens/homePages/goalsPage.dart';
import 'package:money_management/services/Database_Services.dart';
import 'package:money_management/widgets/commonWidgets.dart';
import 'package:money_management/widgets/pinPad.dart';

void main() {
  group('money formatting', () {
    tearDown(() => currencySymbol = '\$');

    test('rounds to at most 2 decimals and adds thousands separators', () {
      expect(moneyText(12.300000000001), ltr('12.3\$'));
      expect(moneyText(1250.5), ltr('1,250.5\$'));
      expect(moneyText(null), ltr('0\$'));
    });

    test('puts a space before multi-letter currencies', () {
      currencySymbol = 'د.ل';
      expect(moneyText(12), ltr('12 د.ل'));
    });
  });

  test('stored dates always use Western digits', () {
    expect(DatabaseHelper().formatDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('friendlyDate uses today / yesterday / weekday names', () {
    final now = DateTime(2026, 10, 15, 9, 30); // a Thursday
    expect(friendlyDate('2026-10-15', now: now), 'اليوم');
    expect(friendlyDate('2026-10-14', now: now), 'أمس');
    expect(friendlyDate('2026-10-12', now: now), 'الاثنين 12 أكتوبر');
    expect(friendlyDate('2025-12-31', now: now), 'الأربعاء 31 ديسمبر 2025');
    expect(friendlyDate('not a date', now: now), 'not a date');
  });

  test('goals: monthly amount needed to reach the target in time', () {
    final now = DateTime(2026, 10, 15);
    expect(monthlyNeeded(1200, 0, '2027-04-15', now: now), 200); // ~6 months
    expect(monthlyNeeded(1200, 1200, '2027-04-15', now: now), isNull); // reached
    expect(monthlyNeeded(1200, 0, '2026-10-01', now: now), isNull); // deadline passed
    expect(monthlyNeeded(1200, 0, null, now: now), isNull); // no deadline
    expect(monthlyNeeded(100, 0, '2026-10-20', now: now), 100); // less than a month
  });

  test('monthTitle shows the Arabic month name', () {
    expect(monthTitle('2026-10-15'), 'أكتوبر 2026');
    expect(monthTitle('not a date'), 'not a date');
  });

  test('Arabic keyboard digits are converted', () {
    final formatter = ArabicDigitsFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '١٢٫٥'),
    );
    expect(result.text, '12.5');
  });

  test('items without a category fall back to "no category"', () {
    expect(categoryOf(null), noCategory);
    expect(categoryOf('unknown'), noCategory);
    expect(categoryOf('food').label, 'طعام');
  });

  test('amount validation', () {
    expect(requiredAmount(''), isNotNull);
    expect(requiredAmount('0'), isNotNull);
    expect(requiredAmount('5'), isNull);
  });

  testWidgets('PIN pad works above the Navigator, where the lock screen is', (tester) async {
    String? entered;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Stack(children: [
        child!,
        Positioned.fill(
          child: Scaffold(
            body: PinPad(
              title: 'lock',
              onBiometric: () {},
              onCompleted: (pin) async {
                entered = pin;
                return null;
              },
            ),
          ),
        ),
      ]),
      home: const SizedBox(),
    ));
    expect(tester.takeException(), isNull);
    for (final digit in ['1', '0', '9', '0']) {
      await tester.tap(find.text(digit).first);
      await tester.pump();
    }
    expect(entered, '1090');
  });

  testWidgets('app starts on the accounts screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('الحسابات'), findsOneWidget);
  });
}

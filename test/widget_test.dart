import 'package:flutter_test/flutter_test.dart';

import 'package:money_management/main.dart';
import 'package:money_management/services/Database_Services.dart';
import 'package:money_management/widgets/commonWidgets.dart';

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

  testWidgets('app starts on the accounts screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('الحسابات'), findsOneWidget);
  });
}

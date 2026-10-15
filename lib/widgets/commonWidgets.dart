import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/Database_Services.dart';

const List<String> arabicMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

// Keeps numbers/dates in left-to-right order inside Arabic text,
// so "2026-10-15" does not show as "15-10-2026".
String ltr(String text) => '\u2066$text\u2069';

// Currency shown after amounts; loaded from settings when the app starts.
String currencySymbol = '\$';

const List<String> currencyChoices = ['\$', '€', 'د.ل', 'ر.س', 'د.إ', 'ج.م', 'د.ت', 'د.ج', 'د.م'];

// Formats an amount for display, e.g. 1250.5 -> "1,250.5$" or "1,250.5 د.ل"
String moneyText(num? value) {
  final amount = DatabaseHelper().formatMoney(value);
  return ltr(currencySymbol.length == 1 ? '$amount$currencySymbol' : '$amount $currencySymbol');
}

class ItemCategory {
  final String key;
  final String label;
  final IconData icon;
  const ItemCategory(this.key, this.label, this.icon);
}

// The stored value is the key, so labels and icons can change safely.
const List<ItemCategory> itemCategories = [
  ItemCategory('food', 'طعام', Icons.restaurant),
  ItemCategory('transport', 'مواصلات', Icons.directions_car),
  ItemCategory('bills', 'فواتير وخدمات', Icons.receipt),
  ItemCategory('health', 'صحة', Icons.medical_services),
  ItemCategory('clothes', 'ملابس', Icons.checkroom),
  ItemCategory('home', 'منزل', Icons.chair),
  ItemCategory('fun', 'ترفيه', Icons.celebration),
  ItemCategory('other', 'أخرى', Icons.category),
];

const ItemCategory noCategory = ItemCategory('', 'بدون تصنيف', Icons.shopping_bag_outlined);

// Old items (saved before categories existed) have no category.
ItemCategory categoryOf(String? key) =>
    itemCategories.firstWhere((c) => c.key == key, orElse: () => noCategory);

// "2026-10-15" -> "أكتوبر 2026"
String monthTitle(String date) {
  final parts = date.split('-');
  final month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  if (month < 1 || month > 12) return date;
  return '${arabicMonths[month - 1]} ${parts[0]}';
}

// Lets users type with an Arabic keyboard: ٠١٢٣٤٥٦٧٨٩ / ۰۱۲۳۴۵۶۷۸۹ -> 0-9, ٫ -> .
class ArabicDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B) {
        buffer.write('.');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    final text = buffer.toString();
    if (text == newValue.text) return newValue;
    return newValue.copyWith(text: text);
  }
}

final List<TextInputFormatter> moneyInputFormatters = [
  ArabicDigitsFormatter(),
  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
];

final List<TextInputFormatter> countInputFormatters = [
  ArabicDigitsFormatter(),
  FilteringTextInputFormatter.digitsOnly,
];

// Brand teal, the same as the app icon.
const Color brandColor = Color(0xFF0E8A73);
// Background of the big balance cards (same gradient as the icon) and the
// text colour on top of it. Used in light and dark mode alike.
const List<Color> brandGradient = [Color(0xFF10967A), Color(0xFF08564C)];
const Color onBrand = Colors.white;

// Bar colour for charts; checked for contrast and colour-blind safety
// against the app's light and dark backgrounds.
Color chartColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF3987E5)
    : const Color(0xFF2A78D6);

// Shows a date picker (no future dates) and returns "yyyy-MM-dd", or null if cancelled.
Future<String?> pickDate(BuildContext context, {String? initial}) async {
  final now = DateTime.now();
  final current = DateTime.tryParse(initial ?? '') ?? now;
  final picked = await showDatePicker(
    context: context,
    initialDate: current.isAfter(now) ? now : current,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  return picked == null ? null : DatabaseHelper().formatDate(picked);
}

String? requiredAmount(String? value) {
  final amount = double.tryParse(value ?? '');
  if (amount == null) return 'أدخل المبلغ';
  if (amount <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
  return null;
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: scheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Coloured card at the top of a screen showing one big amount.
class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? footer;
  const SummaryCard({super.key, required this.label, required this.value, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: brandGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: onBrand.withValues(alpha: 0.85), fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: onBrand, fontSize: 34, fontWeight: FontWeight.bold),
          ),
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

// Coloured bar shown once this month's spending reaches 80% of the budget.
// Shows nothing when there is no budget or spending is still below 80%.
class BudgetWarning extends StatelessWidget {
  final double? budget;
  final double spent;
  const BudgetWarning({super.key, required this.budget, required this.spent});

  @override
  Widget build(BuildContext context) {
    final limit = budget;
    if (limit == null || limit <= 0 || spent < limit * 0.8) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Amber for "almost there", the theme's error colours for "over"
    final background = over
        ? scheme.errorContainer
        : (dark ? const Color(0xFF4A3A10) : const Color(0xFFFFF1D6));
    final foreground = over
        ? scheme.onErrorContainer
        : (dark ? const Color(0xFFFFDFA0) : const Color(0xFF6B4A00));
    final message = over
        ? 'تجاوزت الميزانية الشهرية بمقدار ${moneyText(spent - limit)}'
        : 'اقتربت من الميزانية الشهرية: بقي ${moneyText(limit - spent)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(over ? Icons.error_outline : Icons.warning_amber_rounded, color: foreground),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: foreground, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

// Section title used above lists, e.g. a month name with its total.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

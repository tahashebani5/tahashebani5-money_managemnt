import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/Database_Services.dart';
import '../../widgets/commonWidgets.dart';

class Statisticspage extends StatefulWidget {
  final int account_id;
  const Statisticspage({super.key, required this.account_id});

  @override
  State<Statisticspage> createState() => _StatisticspageState();
}

class _StatisticspageState extends State<Statisticspage> {
  late final Future<List<dynamic>> _data = Future.wait([
    DatabaseHelper().getMonthlyTotals(widget.account_id),
    DatabaseHelper().getTopItems(widget.account_id),
    DatabaseHelper().getCategoryTotals(widget.account_id),
  ]);
  int? _selected;

  String _changeText(double current, double previous) {
    if (previous <= 0) return 'لا يوجد مصروف في الشهر الماضي';
    final percent = ((current - previous) / previous * 100).round();
    if (percent == 0) return 'مثل الشهر الماضي';
    return percent > 0
        ? 'أكثر بـ ${ltr('$percent%')} من الشهر الماضي'
        : 'أقل بـ ${ltr('${-percent}%')} من الشهر الماضي';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: FutureBuilder<List<dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final months = snapshot.data![0] as List<Map<String, dynamic>>;
          final topItems = snapshot.data![1] as List<Map<String, dynamic>>;
          final categoryRows = snapshot.data![2] as List<Map<String, dynamic>>;
          final selected = _selected ?? months.length - 1;
          final current = months.last['spent'] as double;
          final previous = months[months.length - 2]['spent'] as double;
          final spentMonths = months.where((m) => (m['spent'] as double) > 0).toList();
          final average = spentMonths.isEmpty
              ? 0.0
              : spentMonths.fold<double>(0, (s, m) => s + (m['spent'] as double)) / spentMonths.length;
          final month = months[selected];
          final net = (month['deposited'] as double) - (month['spent'] as double);
          // Already sorted biggest first by the query
          final monthCategories = categoryRows.where((r) => r['month'] == month['month']).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatTile(
                      label: 'مصروف هذا الشهر',
                      value: moneyText(current),
                      note: _changeText(current, previous),
                    ),
                    _StatTile(
                      label: 'متوسط المصروف الشهري',
                      value: moneyText(average),
                      note: 'آخر ${months.length} أشهر',
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'المصروف الشهري'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Column(
                    children: [
                      _MonthlyBars(
                        months: months,
                        selected: selected,
                        onSelect: (index) => setState(() => _selected = index),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على أي شهر لرؤية تفاصيله',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const Divider(height: 24),
                      Text(
                        monthTitle('${month['month']}-01'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(label: 'المصروف', value: moneyText(month['spent'])),
                      _DetailRow(label: 'الإيداع', value: moneyText(month['deposited'])),
                      _DetailRow(
                        label: 'الصافي (الإيداع − المصروف)',
                        value: '${net < 0 ? '-' : '+'}${moneyText(net.abs())}',
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(title: 'حسب الفئة · ${monthTitle('${month['month']}-01')}'),
              if (monthCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد مشتريات في هذا الشهر')),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        for (final row in monthCategories)
                          _TopItemRow(
                            icon: categoryOf(row['category'] as String).icon,
                            name: categoryOf(row['category'] as String).label,
                            total: (row['total'] as num).toDouble(),
                            fraction: (row['total'] as num) / (monthCategories.first['total'] as num),
                          ),
                      ],
                    ),
                  ),
                ),
              const SectionHeader(title: 'أكثر ما صرفت عليه'),
              if (topItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد مشتريات بعد')),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        for (final item in topItems)
                          _TopItemRow(
                            name: item['name'] as String,
                            total: (item['total'] as num).toDouble(),
                            count: item['count'] as num,
                            fraction: (item['total'] as num) / (topItems.first['total'] as num),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  const _StatTile({required this.label, required this.value, required this.note});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(note, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// Vertical bars, one per month. The whole column is the tap target and the
// selected month shows its value above the bar.
class _MonthlyBars extends StatelessWidget {
  final List<Map<String, dynamic>> months;
  final int selected;
  final ValueChanged<int> onSelect;
  const _MonthlyBars({required this.months, required this.selected, required this.onSelect});

  static const double _plotHeight = 160;
  // Room above the tallest bar for its value label (Arabic currency text is tall)
  static const double _labelSpace = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = chartColor(context);
    final maxSpent = months.fold<double>(0, (m, e) => math.max(m, e['spent'] as double));
    if (maxSpent == 0) {
      return const SizedBox(
        height: _plotHeight,
        child: Center(child: Text('لا توجد مصروفات في هذه الفترة')),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (i == selected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: FittedBox(
                              child: Text(
                                moneyText(months[i]['spent']),
                                style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                              ),
                            ),
                          ),
                        Container(
                          height: math.max(
                            2,
                            (months[i]['spent'] as double) / maxSpent * (_plotHeight - _labelSpace),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Text(
                    arabicMonths[int.parse((months[i]['month'] as String).substring(5, 7)) - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: i == selected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: i == selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DetailRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final IconData? icon;
  final String name;
  final double total;
  final num? count;
  final double fraction;
  const _TopItemRow({this.icon, required this.name, required this.total, this.count, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
              Text(moneyText(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: scheme.surfaceContainerHighest,
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.02, 1.0),
                child: Container(color: chartColor(context)),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text('الكمية الكلية: $count', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

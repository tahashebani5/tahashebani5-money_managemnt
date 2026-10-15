import 'package:flutter/material.dart';
import '../services/Database_Services.dart';
import '../widgets/commonWidgets.dart';

// Built-in categories (fixed) and the user's own ones (add, rename, delete).
class Categoriespage extends StatefulWidget {
  const Categoriespage({super.key});

  @override
  State<Categoriespage> createState() => _CategoriespageState();
}

class _CategoriespageState extends State<Categoriespage> {
  Future<void> _reload() async {
    await loadCustomCategories();
    if (mounted) setState(() {});
  }

  // Returns (label, iconKey) or null when cancelled.
  Future<(String, String)?> _editDialog({String label = '', String iconKey = 'label'}) {
    final controller = TextEditingController(text: label);
    var selectedIcon = iconKey;
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(label.isEmpty ? 'فئة جديدة' : 'تعديل الفئة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: label.isEmpty,
                    decoration: const InputDecoration(labelText: 'اسم الفئة', hintText: 'مثلاً: قهوة'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in categoryIconChoices.entries)
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setDialogState(() => selectedIcon = entry.key),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: entry.key == selectedIcon ? scheme.primary : scheme.surfaceContainerHigh,
                            foregroundColor: entry.key == selectedIcon ? scheme.onPrimary : scheme.onSurface,
                            child: Icon(entry.value),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
              TextButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) Navigator.of(context).pop((name, selectedIcon));
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add() async {
    final result = await _editDialog();
    if (result == null) return;
    await DatabaseHelper().addCustomCategory(result.$1, result.$2);
    await _reload();
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final result = await _editDialog(label: row['label'] as String, iconKey: (row['icon_key'] as String?) ?? 'label');
    if (result == null) return;
    await DatabaseHelper().updateCustomCategory(row['category_key'] as String, result.$1, result.$2);
    await _reload();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await confirmDialog(
      context,
      title: 'حذف الفئة',
      message: 'ستُحذف فئة "${row['label']}"، والعناصر المصنفة بها ستصبح "بدون تصنيف". لن يُحذف أي عنصر.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;
    await DatabaseHelper().deleteCustomCategory(row['category_key'] as String);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الفئات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('فئة جديدة'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getCustomCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final custom = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const SectionHeader(title: 'فئاتك'),
              if (custom.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لم تضف فئات بعد. أضف فئات تناسبك مثل "قهوة" أو "أطفال" لتظهر عند إضافة العناصر وفي الإحصائيات.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final row in custom)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                      child: Icon(categoryIconChoices[row['icon_key']] ?? Icons.label_outline),
                    ),
                    title: Text(row['label'] as String),
                    onTap: () => _edit(row),
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(row),
                    ),
                  ),
                ),
              const SectionHeader(title: 'الفئات الأساسية'),
              for (final category in itemCategories)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.surfaceContainerHigh,
                      foregroundColor: scheme.onSurfaceVariant,
                      child: Icon(category.icon),
                    ),
                    title: Text(category.label),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

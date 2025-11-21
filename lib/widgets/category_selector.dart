import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel.dart';

class CategorySelector extends StatefulWidget {
  final String initialCategory;
  final Function(String) onChanged;

  const CategorySelector({super.key, required this.initialCategory, required this.onChanged});

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!vm.categories.contains(_selectedCategory) && vm.categories.isNotEmpty) {
       _selectedCategory = vm.categories.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Kategori", 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: theme.colorScheme.onSurface.withOpacity(0.6)
          )
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            ...vm.categories.map((category) {
              final isSelected = category == _selectedCategory;
              return ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedCategory = category);
                    widget.onChanged(category);
                  }
                },
                selectedColor: theme.colorScheme.primary,
                backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!),
                  ),
                ),
                showCheckmark: false,
              );
            }),
            ActionChip(
              label: const Icon(Icons.add, size: 18),
              onPressed: () => _showAddCategoryDialog(context, vm),
              backgroundColor: isDark ? Colors.white10 : Colors.white,
              shape: CircleBorder(
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context, AppViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ny Kategori"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Navn på kategori"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await vm.addNewCategory(controller.text);
                setState(() => _selectedCategory = controller.text);
                widget.onChanged(controller.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Opret"),
          ),
        ],
      ),
    );
  }
}
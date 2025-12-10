import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel.dart';
import '../../models.dart'; // Sørg for at TodoTask er tilgængelig her

class TaskSelectorSheet extends StatefulWidget {
  final Function(TodoTask) onTaskSelected;

  const TaskSelectorSheet({Key? key, required this.onTaskSelected}) : super(key: key);

  @override
  State<TaskSelectorSheet> createState() => _TaskSelectorSheetState();
}

class _TaskSelectorSheetState extends State<TaskSelectorSheet> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vi henter 'allTasks' fra ViewModel - den getter har du allerede!
    final viewModel = Provider.of<AppViewModel>(context);
    final allTasks = viewModel.allTasks;

    // Filtrer opgaver baseret på søgning og udeluk evt. færdige opgaver
    final filteredTasks = allTasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final isNotDone = !task.isCompleted; // Vi vil typisk kun vedhæfte til åbne opgaver
      return matchesSearch && isNotDone;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Tag 70% af skærmen
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Lille "håndtag" øverst
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "Vælg Opgave",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Søgefelt
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Søg efter opgave...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: viewModel.isDarkMode ? Colors.black26 : Colors.grey[100],
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),
          
          // Listen af opgaver
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty 
                          ? "Ingen åbne opgaver fundet." 
                          : "Ingen resultater for '$_searchQuery'",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredTasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final task = filteredTasks[i];
                      // Find listenavnet for kontekst (valgfrit)
                      final listName = viewModel.lists
                          .firstWhere((l) => l.id == task.listId, orElse: () => viewModel.lists.first)
                          .title;

                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Colors.grey),
                        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          "$listName • ${task.priority.name}", 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])
                        ),
                        trailing: const Icon(Icons.add_link, color: Colors.blueAccent),
                        onTap: () => widget.onTaskSelected(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
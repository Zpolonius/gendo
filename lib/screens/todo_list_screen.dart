import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../viewmodel.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/todo_list_card.dart'; // HUSK: Denne fil skal eksistere i widgets mappen

class TodoListScreen extends StatefulWidget {
  final Function(int) onSwitchTab; 
  
  const TodoListScreen({super.key, required this.onSwitchTab});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      // --- ENKEL FAB TIL AT OPRETTE NYE LISTER ---
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_list_main_btn',
        onPressed: () => _showCreateListDialog(context, vm),
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.playlist_add, color: Colors.white),
        label: const Text("Ny Liste", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      
      body: Column(
        children: [
          // --- HEADER ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "MINE LISTER", 
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey[600], 
                  letterSpacing: 1.2
                )
              ),
            ),
          ),

          // --- LISTE OVER LISTER ---
          Expanded(
            child: vm.lists.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("Ingen lister endnu", style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showCreateListDialog(context, vm),
                        child: const Text("Opret din første liste"),
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => vm.loadData(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: vm.lists.length,
                    itemBuilder: (ctx, i) {
                      final list = vm.lists[i];
                      // RETTELSE: Bruger nu TodoListCard fra importen (uden understreg)
                      return TodoListCard(
                        list: list, 
                        vm: vm,
                        onSwitchTab: widget.onSwitchTab
                      );
                    },
                  ),
                  ),
            ),
          ],
        ),
      );
  }

  // --- DIALOGS ---

  void _showCreateListDialog(BuildContext context, AppViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ny Liste"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "F.eks. 'Indkøb' eller 'Projekt X'"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                vm.createList(controller.text);
                Navigator.pop(ctx);
              }
            }, 
            child: const Text("Opret")
          ),
        ],
      ),
    );
  }

  // Add Task dialog (Beholdes som backup eller til global oprettelse)
  void _showAddDialog(BuildContext context, AppViewModel vm) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Generelt';
    DateTime? selectedDate;
    TaskPriority selectedPriority = TaskPriority.medium;
    
    String? targetListId = vm.activeListId ?? (vm.lists.isNotEmpty ? vm.lists.first.id : null);

    // Sikkerhedstjek
    if (targetListId != null) {
      final listExists = vm.lists.any((list) => list.id == targetListId);
      if (!listExists && vm.lists.isNotEmpty) {
        targetListId = vm.lists.first.id;
      }
    } else if (vm.lists.isNotEmpty) {
       targetListId = vm.lists.first.id;
    }

    if (targetListId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opret venligst en liste først!")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Ny Opgave"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: targetListId,
                    decoration: const InputDecoration(labelText: "Tilføj til liste"),
                    items: vm.lists.map((list) => DropdownMenuItem(
                      value: list.id,
                      child: Text(list.title),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => targetListId = val);
                        vm.setActiveList(val); 
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleController, 
                    autofocus: true,
                    decoration: const InputDecoration(labelText: "Titel", hintText: "Hvad skal laves?"),
                  ),
                  const SizedBox(height: 15),
                  CategorySelector(
                    initialCategory: selectedCategory,
                    onChanged: (val) => selectedCategory = val,
                  ),
                  const SizedBox(height: 15),
                  PrioritySelector(
                    initialPriority: selectedPriority,
                    onChanged: (val) => setState(() => selectedPriority = val),
                  ),
                  const SizedBox(height: 15),
                  DateSelector(
                    selectedDate: selectedDate,
                    onDateChanged: (date) => setState(() => selectedDate = date),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Noter/Beskrivelse"),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
              ElevatedButton(onPressed: () {
                if (titleController.text.isNotEmpty && targetListId != null) {
                  vm.setActiveList(targetListId!);
                  vm.addTask(
                    titleController.text,
                    category: selectedCategory,
                    description: descController.text,
                    dueDate: selectedDate, 
                    priority: selectedPriority,
                  );
                  Navigator.pop(context);
                }
              }, child: const Text("Tilføj")),
            ],
          );
        }
      ),
    );
  }
}
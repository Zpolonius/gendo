import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../models/todo_list.dart';

import '../viewmodel.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/todo_list_card.dart';
import '../widgets/repeat_selector.dart'; // NY IMPORT

class TodoListScreen extends StatefulWidget {
  final Function(int) onSwitchTab; 
  
  const TodoListScreen({super.key, required this.onSwitchTab});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  bool _isFabExpanded = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'add_list_btn',
              onPressed: () {
                setState(() => _isFabExpanded = false);
                _showCreateListDialog(context, vm);
              },
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.playlist_add),
              label: const Text("Ny Liste"),
            ),
            const SizedBox(height: 16),
            
            FloatingActionButton.extended(
              heroTag: 'add_task_btn',
              onPressed: () {
                setState(() => _isFabExpanded = false);
                _showAddDialog(context, vm);
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text("Ny Opgave"),
            ),
            const SizedBox(height: 16),
          ],

          FloatingActionButton(
            heroTag: 'main_fab',
            onPressed: () {
              setState(() {
                _isFabExpanded = !_isFabExpanded;
              });
            },
            backgroundColor: _isFabExpanded ? Colors.grey : theme.colorScheme.primary,
            child: Icon(
              _isFabExpanded ? Icons.close : Icons.menu, 
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
      
      body: GestureDetector(
        onTap: () {
          if (_isFabExpanded) setState(() => _isFabExpanded = false);
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
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
      ),
    );
  }

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

  void _showAddDialog(BuildContext context, AppViewModel vm) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDate;
    TaskPriority selectedPriority = TaskPriority.medium;
    TaskRepeat selectedRepeat = TaskRepeat.never; // DEFAULT
    
    String? targetListId = vm.activeListId ?? (vm.lists.isNotEmpty ? vm.lists.first.id : null);

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
                    initialValue: targetListId,
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
                  
                  PrioritySelector(
                    initialPriority: selectedPriority,
                    onChanged: (val) => setState(() => selectedPriority = val),
                  ),
                  const SizedBox(height: 15),
                  
                  // NY: Gentagelse vælger
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DateSelector(
                          selectedDate: selectedDate,
                          onDateChanged: (date) => setState(() => selectedDate = date),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RepeatSelector(
                          initialRepeat: selectedRepeat,
                          onChanged: (val) => setState(() => selectedRepeat = val),
                        ),
                      ),
                    ],
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
                    category: "Generelt", 
                    description: descController.text,
                    dueDate: selectedDate, 
                    priority: selectedPriority,
                    repeat: selectedRepeat, // Sender den valgte gentagelse med
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
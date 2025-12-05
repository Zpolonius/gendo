import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../viewmodel.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/todo_list_card.dart';

import '../widgets/skeleton_loader.dart';

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
           Expanded(child: Builder(
                builder: (context) {
                  // 1. Hvis vi loader, vis Skeleton
                  if (vm.isLoading) {
                    return const SkeletonListLoader();
                  }
                  
                  // 2. Hvis vi er færdige og listen er tom, vis Empty State
                  if (vm.lists.isEmpty) {
                    return Center(
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
                    );
                  }

                  // 3. Ellers vis den rigtige liste
                  return RefreshIndicator(
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
                  );
                },
              ),
            ),
        ]),
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
    
    // Vi fjerner TaskRepeat logikken herfra, da den ikke skal bruges i dialogen
    
    // Logik til at vælge standard-liste
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
            // Vi bruger SingleChildScrollView så tastaturet ikke dækker felterne
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Vælg Liste
                  DropdownButtonFormField<String>(
                    initialValue: targetListId,
                    decoration: const InputDecoration(
                      labelText: "Tilføj til liste",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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
                  const SizedBox(height: 16),
                  
                  // 2. Titel (Fokus her fra start)
                  TextField(
                    controller: titleController, 
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: "Titel", 
                      hintText: "Hvad skal laves?",
                      border: OutlineInputBorder(),
                      filled: true,
                      // fillColor: Theme.of(context).cardColor, // Valgfrit
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Dato / Deadline (Flyttet OP og gjort tydelig)
                  const Text("Deadline", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                     
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DateSelector(
                      selectedDate: selectedDate,
                      onDateChanged: (date) => setState(() => selectedDate = date),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 4. Prioritet
                  const Text("Prioritet", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  PrioritySelector(
                    initialPriority: selectedPriority,
                    onChanged: (val) => setState(() => selectedPriority = val),
                  ),
                  const SizedBox(height: 16),
                  
                  // 5. Noter (Fixet version)
                  const Text("Noter", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    minLines: 3, // Sikrer en god højde fra start
                    maxLines: 5, // Tillader lidt mere tekst uden at sprænge layoutet
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white), // Sikrer læsbarhed
                    decoration: InputDecoration(
                      hintText: "Tilføj beskrivelse...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2E), // Mørk baggrund
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && targetListId != null) {
                    vm.setActiveList(targetListId!);
                    vm.addTask(
                      titleController.text,
                      category: "Generelt", 
                      description: descController.text,
                      dueDate: selectedDate, 
                      priority: selectedPriority,
                      repeat: TaskRepeat.never, // Vi sender 'never' da repeat-vælgeren er fjernet
                    );
                    Navigator.pop(context);
                  }
                }, 
                child: const Text("Tilføj")
              ),
            ],
          );
        }
      ),
    );
}}
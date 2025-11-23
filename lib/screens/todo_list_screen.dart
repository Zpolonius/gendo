import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/todo_list.dart';
import '../models.dart';
import '../viewmodel.dart';
import 'task_detail_screen.dart';
import '../widgets/category_selector.dart';
import '../widgets/priority_selector.dart';
import '../widgets/date_selector.dart';

class TodoListScreen extends StatefulWidget {
  final Function(int) onSwitchTab; 
  
  const TodoListScreen({super.key, required this.onSwitchTab});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  // State til at styre om menuen er åben
  bool _isFabExpanded = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // --- TRIN 1: SAMLET KNAP (SPEED DIAL) ---
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hvis menuen er åben, vis de to knapper
          if (_isFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'add_list_btn',
              onPressed: () {
                setState(() => _isFabExpanded = false); // Luk menu efter valg
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
                setState(() => _isFabExpanded = false); // Luk menu efter valg
                _showAddDialog(context, vm);
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text("Ny Opgave"),
            ),
            const SizedBox(height: 16),
          ],

          // Hovedknappen (Åbn/Luk)
          FloatingActionButton(
            heroTag: 'main_fab',
            onPressed: () {
              setState(() {
                _isFabExpanded = !_isFabExpanded;
              });
            },
            backgroundColor: _isFabExpanded ? Colors.grey : theme.colorScheme.primary,
            child: Icon(
              _isFabExpanded ? Icons.close : Icons.add, 
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
      
      // Klik på baggrunden for at lukke menuen (valgfrit men god UX)
      body: GestureDetector(
        onTap: () {
          if (_isFabExpanded) setState(() => _isFabExpanded = false);
        },
        behavior: HitTestBehavior.translucent, // Sikrer at taps registreres selv på tomme områder
        child: Column(
          children: [
            // --- HEADER: MINE LISTER ---
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
                        final listTasks = vm.allTasks.where((t) => t.listId == list.id).toList();
                        final isOwner = currentUser?.uid == list.ownerId;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              onExpansionChanged: (expanded) {
                                if (expanded) vm.setActiveList(list.id);
                              },
                              backgroundColor: theme.colorScheme.surface,
                              collapsedBackgroundColor: theme.colorScheme.surface,
                              title: Text(
                                list.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                "${listTasks.length} opgaver • ${list.memberIds.length} medlemmer",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.list, color: theme.colorScheme.primary, size: 20),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'invite') _showInviteDialog(context, vm, list);
                                  if (value == 'delete') _showDeleteListDialog(context, vm, list);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'invite',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_add_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text("Inviter medlem"),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Slet liste", style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                if (listTasks.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text("Ingen opgaver i denne liste.", style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic)),
                                  )
                                else
                                  ...listTasks.map((task) => _TaskCard(
                                    task: task, 
                                    onTap: () => _openTaskDetail(context, task, vm),
                                    onToggle: () => vm.toggleTask(task.id),
                                    // onDelete: () => vm.deleteTask(task.id), // FJERNES HERFRA (Trin 2)
                                    compact: true,
                                  )),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
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

  // --- DIALOGS ---

  void _openTaskDetail(BuildContext context, TodoTask task, AppViewModel vm) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: task.id, 
          initialTask: task,
          onStartTask: () {
            vm.setSelectedTask(task.id);
            Navigator.pop(context);
            widget.onSwitchTab(0); 
          },
        )
      )
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

  void _showInviteDialog(BuildContext context, AppViewModel vm, TodoList list) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Inviter til '${list.title}'"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Indtast e-mailen på den bruger, du vil invitere:", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "E-mail",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await vm.inviteUser(list.id, controller.text.trim());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invitation sendt!")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e"), backgroundColor: Colors.red));
                }
              }
            }, 
            child: const Text("Inviter")
          ),
        ],
      ),
    );
  }

  void _showDeleteListDialog(BuildContext context, AppViewModel vm, TodoList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Slet Liste?"),
        content: Text("Er du sikker på, at du vil slette '${list.title}' og alle dens opgaver? Dette kan ikke fortrydes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          TextButton(
            onPressed: () {
              vm.deleteList(list.id);
              Navigator.pop(ctx);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Slet"),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, AppViewModel vm) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Generelt';
    DateTime? selectedDate;
    TaskPriority selectedPriority = TaskPriority.medium;
    
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

// Genbruger TaskCard, men tilføjer en 'compact' mode til visning i lister
class _TaskCard extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  // final VoidCallback onDelete; // FJERNES: Ikke brug for delete her mere
  final bool compact;

  const _TaskCard({
    required this.task, 
    required this.onTap, 
    required this.onToggle, 
    // required this.onDelete, // FJERNES
    this.compact = false,
  });

  Color _getPriorityColor(TaskPriority p) {
    switch(p) {
      case TaskPriority.high: return Colors.redAccent;
      case TaskPriority.medium: return Colors.orangeAccent;
      case TaskPriority.low: return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('dd/MM');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: compact ? Colors.transparent : theme.colorScheme.surface,
          border: compact 
              ? Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200))
              : Border.all(color: isDark ? Colors.white10 : Colors.transparent),
          borderRadius: compact ? BorderRadius.circular(0) : BorderRadius.circular(16),
          boxShadow: (!compact && !isDark) ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 0 : 12),
          leading: IconButton(
            icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined),
            color: task.isCompleted ? Colors.green : Colors.grey,
            onPressed: onToggle,
          ),
          title: Text(
            task.title, 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: task.isCompleted ? Colors.grey : theme.colorScheme.onSurface,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            )
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priority.name.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPriorityColor(task.priority)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (task.dueDate != null) ...[
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormatter.format(task.dueDate!),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ]
                ],
              ),
            ],
          ),
          // trailing: IconButton(...) ER NU FJERNET
        ),
      ),
    );
  }
}
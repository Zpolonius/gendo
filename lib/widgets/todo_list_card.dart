import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodel.dart';
import '../screens/task_detail_screen.dart';
import 'task_card.dart';
import 'member_management_dialog.dart';

// Enum til at definere sorteringsmulighederne
enum ListSortOption {
  priority,
  date,
  alphabetical,
}

class TodoListCard extends StatefulWidget {
  final TodoList list;
  final AppViewModel vm;
  final Function(int) onSwitchTab;

  const TodoListCard({
    super.key,
    required this.list, 
    required this.vm,
    required this.onSwitchTab
  });

  @override
  State<TodoListCard> createState() => _TodoListCardState();
}

class _TodoListCardState extends State<TodoListCard> {
  final TextEditingController _quickAddController = TextEditingController();
  
  // Standard sortering: Prioritet
  ListSortOption _currentSort = ListSortOption.priority;

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  void _addTaskToList() {
    final text = _quickAddController.text.trim();
    if (text.isNotEmpty) {
      widget.vm.setActiveList(widget.list.id);
      widget.vm.addTask(text);
      _quickAddController.clear();
    }
  }

  void _openTaskDetail(BuildContext context, TodoTask task) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: task.id, 
          initialTask: task,
          onStartTask: () {
            widget.vm.setSelectedTask(task.id);
            Navigator.pop(context);
            widget.onSwitchTab(0); 
          },
        )
      )
    );
  }

  void _showMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => MemberManagementDialog(list: widget.list),
    );
  }

  void _showDeleteListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Slet Liste?"),
        content: Text("Er du sikker på, at du vil slette '${widget.list.title}' og alle dens opgaver? Dette kan ikke fortrydes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuller")),
          TextButton(
            onPressed: () {
              widget.vm.deleteList(widget.list.id);
              Navigator.pop(ctx);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Slet"),
          ),
        ],
      ),
    );
  }

  // --- SORTERINGS LOGIK ---
  List<TodoTask> _getSortedTasks(List<TodoTask> tasks) {
    // Vi laver en kopi af listen for ikke at sortere den originale liste i memory direkte (good practice)
    List<TodoTask> sortedTasks = List.from(tasks);

    switch (_currentSort) {
      case ListSortOption.priority:
        sortedTasks.sort((a, b) {
          // TaskPriority enum er: low, medium, high. 
          // Vi vil have High (index 2) først, så vi sorterer b mod a.
          int priorityComp = b.priority.index.compareTo(a.priority.index);
          if (priorityComp != 0) return priorityComp;
          // Hvis samme prioritet, brug oprettelsesdato (nyeste først)
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
        
      case ListSortOption.date:
        sortedTasks.sort((a, b) {
          // Håndter null datoer (opgaver uden deadline lægges til sidst)
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          // Dato: Snarest først
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
        
      case ListSortOption.alphabetical:
        sortedTasks.sort((a, b) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return sortedTasks;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.list.ownerId;
    
    // Hent opgaver og sorter dem
  
    final showCompletedTasks = widget.vm.showCompletedTasks(widget.list.id);
    
    final rawTasks = widget.vm.getFilteredTasks(widget.list.id);
    final sortedTasks = _getSortedTasks(rawTasks);

    final isDark = theme.brightness == Brightness.dark;

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
            if (expanded) widget.vm.setActiveList(widget.list.id);
          },
          backgroundColor: theme.colorScheme.surface,
          collapsedBackgroundColor: theme.colorScheme.surface,
          title: Text(
            widget.list.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            "${sortedTasks.length} opgaver • ${widget.list.memberIds.length} medlemmer",
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
          // --- OPDATERET TRAILING: Sortering + Menu ---
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sorterings knap
              PopupMenuButton<ListSortOption>(
                icon: Icon(Icons.sort_rounded, color: theme.colorScheme.primary.withOpacity(0.7)),
                tooltip: "Sortering",
                onSelected: (ListSortOption option) {
                  setState(() {
                    _currentSort = option;
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<ListSortOption>>[
                  PopupMenuItem<ListSortOption>(
                    value: ListSortOption.priority,
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, 
                          color: _currentSort == ListSortOption.priority ? theme.colorScheme.primary : Colors.grey, 
                          size: 20
                        ),
                        const SizedBox(width: 12),
                        Text("Prioritet (Høj-Lav)", 
                          style: TextStyle(fontWeight: _currentSort == ListSortOption.priority ? FontWeight.bold : FontWeight.normal)
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<ListSortOption>(
                    value: ListSortOption.date,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, 
                          color: _currentSort == ListSortOption.date ? theme.colorScheme.primary : Colors.grey, 
                          size: 20
                        ),
                        const SizedBox(width: 12),
                        Text("Dato (Snarest)", 
                           style: TextStyle(fontWeight: _currentSort == ListSortOption.date ? FontWeight.bold : FontWeight.normal)
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<ListSortOption>(
                    value: ListSortOption.alphabetical,
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha_outlined, 
                          color: _currentSort == ListSortOption.alphabetical ? theme.colorScheme.primary : Colors.grey, 
                          size: 20
                        ),
                        const SizedBox(width: 12),
                        Text("Alfabetisk (A-Å)", 
                           style: TextStyle(fontWeight: _currentSort == ListSortOption.alphabetical ? FontWeight.bold : FontWeight.normal)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Eksisterende Menu (Medlemmer / Slet /filtre)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'toggle_completed') widget.vm.toggleShowCompletedTasks(widget.list.id);
                  if (value == 'members') _showMembersDialog(context);
                  if (value == 'delete') _showDeleteListDialog(context);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle_completed',
                      child: Row(
                        children: [
                          Icon(
                            showCompletedTasks ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
                            size: 20,
                            color: Colors.grey
                          ),
                          const SizedBox(width: 8),
                          Text(showCompletedTasks ? "Skjul færdige" : "Vis færdige"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.group_outlined, size: 20),
                        SizedBox(width: 8),
                        Text("Medlemmer"),
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
            ],
          ),

          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _quickAddController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTaskToList(),
                  decoration: InputDecoration(
                    hintText: "Tilføj opgave til ${widget.list.title}...",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.add, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.save, color: theme.colorScheme.primary),
                      onPressed: _addTaskToList,
                      tooltip: "Gem opgave",
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            if (sortedTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Ingen opgaver endnu.", style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic)),
              )
            else
              // Bruger nu 'sortedTasks' i stedet for 'listTasks'
              ...sortedTasks.map((task) => TaskCard(
                task: task, 
                onTap: () => _openTaskDetail(context, task),
                onToggle: () => widget.vm.toggleTask(task.id),
                compact: true,
              )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
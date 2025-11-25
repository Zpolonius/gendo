import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models.dart';
import '../models/todo_list.dart';
import '../viewmodel.dart';
import '../screens/task_detail_screen.dart';
import 'task_card.dart';
import 'member_management_dialog.dart';

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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.list.ownerId;
    final isDark = theme.brightness == Brightness.dark;

    // 1. Hent alle opgaver til denne liste
    final allListTasks = widget.vm.allTasks.where((t) => t.listId == widget.list.id).toList();
    final showCompleted = widget.list.showCompleted;
    
    // 2. Filtrer listen: Skal vi vise alt eller kun aktive?
    // Vi bruger List.from() for at lave en kopi vi kan sortere i
    List<TodoTask> visibleTasks = List.from(
      showCompleted 
          ? allListTasks 
          : allListTasks.where((t) => !t.isCompleted)
    );

    // 3. SORTERING (NY LOGIK)
    visibleTasks.sort((a, b) {
      // Regel 1: Færdige opgaver skal altid nederst
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1; // Hvis a er færdig (true), ryger den bagud (1)
      }
      
      // Regel 2: Hvis begge har samme status, sorter efter nyeste først (createdAt)
      // Dette sikrer at listen ikke "hopper rundt" tilfældigt
      return b.createdAt.compareTo(a.createdAt);
    });

    // Statistik til undertitlen
    final activeCount = allListTasks.where((t) => !t.isCompleted).length;

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
            showCompleted 
                ? "${allListTasks.length} opgaver • ${widget.list.memberIds.length} medlemmer"
                : "$activeCount opgaver (af ${allListTasks.length}) • ${widget.list.memberIds.length} medlemmer",
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
              if (value == 'members') _showMembersDialog(context);
              if (value == 'delete') _showDeleteListDialog(context);
              if (value == 'toggle_completed') widget.vm.toggleListShowCompleted(widget.list.id);
            },
            itemBuilder: (context) => [
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
              PopupMenuItem(
                value: 'toggle_completed',
                child: Row(
                  children: [
                    Icon(showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    SizedBox(width: 8),
                    Text(showCompleted ? "Skjul færdige" : "Vis færdige"),
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

            if (visibleTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      allListTasks.isEmpty 
                          ? "Ingen opgaver endnu." 
                          : "Alle opgaver er færdige! 🎉", 
                      style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
                    ),
                    if (allListTasks.isNotEmpty && !showCompleted)
                      TextButton(
                        onPressed: () => widget.vm.toggleListShowCompleted(widget.list.id),
                        child: const Text("Vis færdige opgaver", style: TextStyle(fontSize: 12)),
                      )
                  ],
                ),
              )
            else
              ...visibleTasks.map((task) => TaskCard(
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
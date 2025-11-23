import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel.dart';
import '../widgets/todo_list_card.dart'; // HUSK AT IMPORTERE DEN NYE WIDGET

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
                      // Her bruger vi den nye widget fra lib/widgets/todo_list_card.dart
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
}
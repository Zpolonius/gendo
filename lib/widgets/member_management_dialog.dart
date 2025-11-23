import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo_list.dart';
import '../viewmodel.dart';

class MemberManagementDialog extends StatefulWidget {
  final TodoList list;

  const MemberManagementDialog({super.key, required this.list});

  @override
  State<MemberManagementDialog> createState() => _MemberManagementDialogState();
}

class _MemberManagementDialogState extends State<MemberManagementDialog> {
  bool _isLoading = true;
  List<Map<String, String>> _members = [];
  final TextEditingController _inviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final vm = context.read<AppViewModel>();
    final members = await vm.getListMembers(widget.list.id);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  void _inviteUser() async {
    final email = _inviteController.text.trim();
    if (email.isEmpty) return;

    final vm = context.read<AppViewModel>();
    try {
      await vm.inviteUser(widget.list.id, email);
      _inviteController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invitation sendt!")));
        vm.loadData(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _removeMember(String userId) async {
    final vm = context.read<AppViewModel>();
    try {
      await vm.removeMember(widget.list.id, userId);
      _loadMembers(); 
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.list.ownerId;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text("Medlemmer af '${widget.list.title}'"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LISTE OVER MEDLEMMER ---
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_members.isEmpty)
              const Text("Ingen medlemmer fundet (fejl?)")
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _members.length,
                  itemBuilder: (ctx, i) {
                    final member = _members[i];
                    final isMe = member['id'] == currentUser?.uid;
                    final isMemberOwner = member['id'] == widget.list.ownerId;
                    
                    // Vi bruger nu 'displayName' hvis den findes, ellers email
                    final nameToShow = member['displayName'] ?? member['email'] ?? "Ukendt";
                    final emailToShow = member['email'] ?? "";

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        // Vis første bogstav af navnet
                        child: Text(
                          nameToShow.isNotEmpty ? nameToShow[0].toUpperCase() : "?", 
                          style: TextStyle(color: theme.colorScheme.primary)
                        ),
                      ),
                      // FIX: Vis Navn (displayName) her i stedet for kun email
                      title: Text(
                        nameToShow + (isMe ? " (Dig)" : ""), 
                        style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)
                      ),
                      // FIX: Vis E-mail og Ejer-status i underteksten
                      subtitle: Text(
                        isMemberOwner ? "Ejer • $emailToShow" : emailToShow,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: (isOwner && !isMemberOwner) 
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeMember(member['id']!),
                            tooltip: "Fjern medlem",
                          )
                        : null,
                    );
                  },
                ),
              ),
            
            // --- VENTENDE INVITATIONER ---
            if (widget.list.pendingEmails.isNotEmpty) ...[
              const Divider(),
              const Text("Venter på svar:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ...widget.list.pendingEmails.map((email) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(email, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              )),
            ],

            const SizedBox(height: 20),
            const Divider(),
            
            // --- INVITER NY ---
            const Text("Inviter ny:", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteController,
                    decoration: const InputDecoration(hintText: "E-mail", border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _inviteUser,
                )
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Luk")),
      ],
    );
  }
}
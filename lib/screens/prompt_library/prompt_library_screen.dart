import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../viewmodels/app_view_model.dart';
import '../../models/prompt_model.dart';
import 'task_selector_sheet.dart';

class PromptLibraryScreen extends StatefulWidget {
  const PromptLibraryScreen({super.key});

  @override
  State<PromptLibraryScreen> createState() => _PromptLibraryScreenState();
}

class _PromptLibraryScreenState extends State<PromptLibraryScreen> {
  
  // --- NAVIGATION ---
  void _handleUsePrompt(BuildContext context, PromptModel prompt) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Opret som ny opgave'),
              onTap: () {
                Navigator.pop(ctx);
                _showListSelector(context, prompt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Vedhæft til eksisterende opgave'),
              onTap: () {
                Navigator.pop(ctx);
                _showTaskSelector(context, prompt);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showListSelector(BuildContext context, PromptModel prompt) {
    final viewModel = Provider.of<AppViewModel>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Vælg liste", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: viewModel.lists.length,
                  itemBuilder: (ctx, i) {
                    final list = viewModel.lists[i];
                    return ListTile(
                      title: Text(list.title),
                      onTap: () {
                        viewModel.createTodoFromPrompt(prompt, targetListId: list.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Oprettet i ${list.title}")));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTaskSelector(BuildContext context, PromptModel prompt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskSelectorSheet(
        onTaskSelected: (task) async {
          final viewModel = Provider.of<AppViewModel>(context, listen: false);
          await viewModel.attachPromptToTask(task, prompt);
          if (mounted) Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vedhæftet til '${task.title}'")));
        },
      ),
    );
  }

  void _showPromptEditor({PromptModel? prompt}) {
    showDialog(
      context: context,
      builder: (context) {
        final vm = Provider.of<AppViewModel>(context, listen: false);
        return _PromptEditorDialog(
          onSave: (p) => prompt == null ? vm.addPrompt(p) : vm.updatePrompt(p),
          onOptimize: (text) => vm.optimerPromptText(text),
          existingPrompt: prompt,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AppViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prompt Database"),
        // Vi fjerner '+' ikonet i toppen, da vi nu har en FAB i bunden
      ),
      // --- HER ER DIN NYE FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPromptEditor(),
        backgroundColor: Theme.of(context).colorScheme.primary, // Bruger appens primære farve
        foregroundColor: Theme.of(context).colorScheme.onPrimary, // Sikrer teksten er læsbar (hvid på blå etc.)
        tooltip: 'Opret ny prompt',
        child: const Icon(Icons.add_outlined),
      ),
      body: StreamBuilder<List<PromptModel>>(
        stream: viewModel.promptsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Fejl: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final prompts = snapshot.data!;

          if (prompts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Ingen gemte prompts endnu."),
                  TextButton(onPressed: () => _showPromptEditor(), child: const Text("Opret din første prompt")),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: prompts.length,
            // Vi tilføjer 80px padding i bunden, så knappen ikke dækker den sidste prompt
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(prompt.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          prompt.content, 
                          maxLines: 4, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showPromptEditor(prompt: prompt),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => viewModel.deletePrompt(prompt.id),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text("Brug Prompt"),
                            onPressed: () => _handleUsePrompt(context, prompt),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- OPTIMERET EDITOR DIALOG MED VALIDERING ---
class _PromptEditorDialog extends StatefulWidget {
  final Future<void> Function(PromptModel) onSave;
  final Future<String> Function(String) onOptimize;
  final PromptModel? existingPrompt;

  const _PromptEditorDialog({
    required this.onSave,
    required this.onOptimize,
    this.existingPrompt,
  });

  @override
  State<_PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<_PromptEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _isOptimizing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPrompt != null) {
      _titleCtrl.text = widget.existingPrompt!.title;
      _contentCtrl.text = widget.existingPrompt!.content;
      _tagsCtrl.text = widget.existingPrompt!.tags.join(', ');
    }
  }

  Future<void> _optimize() async {
    if (_contentCtrl.text.isEmpty) return;
    setState(() => _isOptimizing = true);
    final optimized = await widget.onOptimize(_contentCtrl.text);
    if (mounted) {
      setState(() {
        _contentCtrl.text = optimized;
        _isOptimizing = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tags = _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      final prompt = PromptModel(
        id: widget.existingPrompt?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        tags: tags,
        createdAt: widget.existingPrompt?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.onSave(prompt);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingPrompt != null ? 'Rediger Prompt' : 'Ny AI Prompt'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: "Titel", border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Titel mangler' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl, 
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: "Prompt Indhold",
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    icon: _isOptimizing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.purple),
                    onPressed: _optimize,
                    tooltip: "Optimer med AI",
                  )
                ),
                validator: (value) => value == null || value.isEmpty ? 'Indhold mangler' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsCtrl, 
                decoration: const InputDecoration(labelText: "Tags (komma-separeret)", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
        ElevatedButton(
          onPressed: _isSaving ? null : _save, 
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Gem"),
        ),
      ],
    );
  }
}
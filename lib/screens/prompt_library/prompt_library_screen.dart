import 'package:flutter/material.dart';
import 'package:gendo/services/prompt_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../viewmodel.dart';
import '../../models/prompt_model.dart';

import 'task_selector_sheet.dart';
import '../../viewmodels/app_view_model.dart';

class PromptLibraryScreen extends StatefulWidget {
  const PromptLibraryScreen({Key? key}) : super(key: key);

  @override
  State<PromptLibraryScreen> createState() => _PromptLibraryScreenState();
}

class _PromptLibraryScreenState extends State<PromptLibraryScreen> {

 

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AppViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prompt Database"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => viewModel.addPrompt,
            tooltip: 'Ny Prompt',
          ),
        ],
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
                  const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Ingen gemte prompts endnu."),
                  TextButton(
                    onPressed: () => viewModel.addPrompt,
                    child: const Text("Opret din første prompt"),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: prompts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  title: Text(
                    prompt.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    prompt.tags.isNotEmpty ? "Tags: ${prompt.tags.join(', ')}" : "Ingen tags",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: viewModel.isDarkMode ? Colors.black26 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(prompt.content, style: const TextStyle(fontFamily: 'monospace')),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text("Rediger"),
                                onPressed: () => viewModel.updatePrompt,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text("Omdan til Opgave"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  // INTEGRATION: Kald ViewModel
                                  viewModel.createTodoFromPrompt(prompt);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Opgave '${prompt.title}' oprettet i aktiv liste!")),
                                  );
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Simpel Editor Dialog (Intern klasse eller separat fil)
class _PromptEditorDialog extends StatefulWidget {
  final FirestorePromptService service;
  final PromptModel? existingPrompt;

  const _PromptEditorDialog({required this.service, this.existingPrompt});

  @override
  State<_PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<_PromptEditorDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagsCtrl;
  bool _isOptimizing = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingPrompt?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existingPrompt?.content ?? '');
    _tagsCtrl = TextEditingController(text: widget.existingPrompt?.tags.join(', ') ?? '');
  }

  Future<void> _optimize() async {
    setState(() => _isOptimizing = true);
    // Her kalder vi vores Future-Proof metode
    final optimized = await widget.service.optimizePrompt(_contentCtrl.text);
    setState(() {
      _contentCtrl.text = optimized;
      _isOptimizing = false;
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) return;

    final tags = _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    final prompt = PromptModel(
      id: widget.existingPrompt?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      tags: tags,
      createdAt: widget.existingPrompt?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.existingPrompt != null) {
      await widget.service.updatePrompt(prompt);
    } else {
      await widget.service.addPrompt(prompt);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingPrompt != null ? 'Rediger Prompt' : 'Ny AI Prompt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titel (f.eks. "SoMe Plan")'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                labelText: 'Prompt indhold',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: _isOptimizing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.auto_awesome, color: Colors.purple),
                  onPressed: _optimize,
                  tooltip: 'AI Optimize (Demo)',
                ),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(labelText: 'Tags (komma-separeret)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuller")),
        ElevatedButton(onPressed: _save, child: const Text("Gem")),
      ],
    );
  }
}
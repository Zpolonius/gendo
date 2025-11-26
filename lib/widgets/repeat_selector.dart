import 'package:flutter/material.dart';
import '../models.dart';

class RepeatSelector extends StatefulWidget {
  final TaskRepeat initialRepeat;
  final Function(TaskRepeat) onChanged;

  const RepeatSelector({super.key, required this.initialRepeat, required this.onChanged});

  @override
  State<RepeatSelector> createState() => _RepeatSelectorState();
}

class _RepeatSelectorState extends State<RepeatSelector> {
  late TaskRepeat _selectedRepeat;

  @override
  void initState() {
    super.initState();
    _selectedRepeat = widget.initialRepeat;
  }

  String _getLabel(TaskRepeat r) {
    switch(r) {
      case TaskRepeat.never: return "Aldrig";
      case TaskRepeat.daily: return "Dagligt";
      case TaskRepeat.weekly: return "Ugentligt";
      case TaskRepeat.monthly: return "Månedligt";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gentagelse", 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: theme.colorScheme.onSurface.withOpacity(0.6)
          )
        ),
        const SizedBox(height: 8),
        // Vi bruger en DropdownButton for at spare plads, da tekst kan være lang
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TaskRepeat>(
              value: _selectedRepeat,
              isDense: true,
              icon: Icon(Icons.repeat, color: theme.colorScheme.primary, size: 20),
              items: TaskRepeat.values.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(_getLabel(r), style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRepeat = val);
                  widget.onChanged(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
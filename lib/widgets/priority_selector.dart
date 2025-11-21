import 'package:flutter/material.dart';
import '../models.dart';

class PrioritySelector extends StatefulWidget {
  final TaskPriority initialPriority;
  final Function(TaskPriority) onChanged;

  const PrioritySelector({super.key, required this.initialPriority, required this.onChanged});

  @override
  State<PrioritySelector> createState() => _PrioritySelectorState();
}

class _PrioritySelectorState extends State<PrioritySelector> {
  late TaskPriority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.initialPriority;
  }

  Color _getColor(TaskPriority p) {
    switch(p) {
      case TaskPriority.high: return Colors.redAccent;
      case TaskPriority.medium: return Colors.orangeAccent;
      case TaskPriority.low: return Colors.greenAccent;
    }
  }
  
  String _getLabel(TaskPriority p) {
     switch(p) {
      case TaskPriority.high: return "Høj";
      case TaskPriority.medium: return "Mellem";
      case TaskPriority.low: return "Lav";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Prioritet", 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
          )
        ),
        const SizedBox(height: 8),
        Row(
          children: TaskPriority.values.map((priority) {
            final isSelected = _selectedPriority == priority;
            final color = _getColor(priority);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(_getLabel(priority)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPriority = priority);
                    widget.onChanged(priority);
                  }
                },
                selectedColor: color.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                ),
                side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
                backgroundColor: Colors.transparent,
                showCheckmark: false,
                avatar: isSelected ? Icon(Icons.check, size: 16, color: color) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
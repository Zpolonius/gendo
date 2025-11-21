import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel.dart';
import '../models.dart';

class PomodoroSettingsScreen extends StatefulWidget {
  const PomodoroSettingsScreen({super.key});

  @override
  State<PomodoroSettingsScreen> createState() => _PomodoroSettingsScreenState();
}

class _PomodoroSettingsScreenState extends State<PomodoroSettingsScreen> {
  late double _workDuration;
  late bool _enableBreaks;
  late bool _enableLongBreaks;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppViewModel>().pomodoroSettings;
    _workDuration = settings.workDurationMinutes.toDouble();
    _enableBreaks = settings.enableBreaks;
    _enableLongBreaks = settings.enableLongBreaks;
  }

  void _saveSettings() {
    final newSettings = PomodoroSettings(
      workDurationMinutes: _workDuration.round(),
      enableBreaks: _enableBreaks,
      enableLongBreaks: _enableLongBreaks,
    );
    context.read<AppViewModel>().updateSettings(newSettings);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Indstillinger gemt!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pomodoro Indstillinger"),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text("GEM", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("TIMER VARIGHED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          
          // Work Duration Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Fokus tid", style: theme.textTheme.titleMedium),
              Text("${_workDuration.round()} min", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _workDuration,
            min: 5,
            max: 90,
            divisions: 17, // 5 min step
            label: "${_workDuration.round()} min",
            onChanged: (val) => setState(() => _workDuration = val),
          ),
          
          const SizedBox(height: 40),
          const Text("PAUSER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          // Enable Breaks Switch
          SwitchListTile(
            title: const Text("Tillad Pauser"),
            subtitle: const Text("Automatisk pause efter hver session"),
            value: _enableBreaks,
            onChanged: (val) => setState(() {
              _enableBreaks = val;
              if (!val) _enableLongBreaks = false; // Slå lang pause fra hvis pauser er slået fra
            }),
          ),

          // Enable Long Breaks Switch
          SwitchListTile(
            title: const Text("Lange Pauser"),
            subtitle: const Text("En længere pause efter 3 sessioner"),
            value: _enableLongBreaks,
            // Kun aktiv hvis pauser generelt er slået til
            onChanged: _enableBreaks ? (val) => setState(() => _enableLongBreaks = val) : null, 
          ),
        ],
      ),
    );
  }
}
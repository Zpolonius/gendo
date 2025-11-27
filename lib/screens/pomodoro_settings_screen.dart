import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel.dart';
import '../models.dart';
import '../widgets/circular_time_picker.dart'; // HUSK AT OPRETTE DENNE FIL

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("TIMER VARIGHED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 30),
            
            // --- DET NYE DREJEHJUL ---
            SizedBox(
              height: 280,
              width: 280,
              child: CircularTimePicker(
                value: _workDuration,
                min: 5,  // Minimum 5 minutter
                max: 60, // Maksimum 60 minutter (en hel omgang)
                color: theme.colorScheme.primary,
                onChanged: (newValue) {
                  setState(() => _workDuration = newValue);
                },
              ),
            ),
            
            const SizedBox(height: 10),
            const Text("Drej for at indstille tiden", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 50),
            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("PAUSER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 10),

            // Enable Breaks Switch
            Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Tillad Pauser"),
                    subtitle: const Text("Automatisk pause efter hver session"),
                    value: _enableBreaks,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (val) => setState(() {
                      _enableBreaks = val;
                      if (!val) _enableLongBreaks = false; 
                    }),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Enable Long Breaks Switch
                  SwitchListTile(
                    title: const Text("Lange Pauser"),
                    subtitle: const Text("En længere pause efter 3 sessioner"),
                    value: _enableLongBreaks,
                    activeThumbColor: theme.colorScheme.primary,
                    // Kun aktiv hvis pauser generelt er slået til
                    onChanged: _enableBreaks ? (val) => setState(() => _enableLongBreaks = val) : null, 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
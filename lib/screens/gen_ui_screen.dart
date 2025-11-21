import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel.dart';

class GenUiScreen extends StatefulWidget {
  const GenUiScreen({super.key});

  @override
  State<GenUiScreen> createState() => _GenUiScreenState();
}

class _GenUiScreenState extends State<GenUiScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final theme = Theme.of(context);
    final isDark = vm.isDarkMode;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/gendo_logo.png', height: 80),
          const SizedBox(height: 20),
          Text("Hvad vil du opnå?", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Beskriv dit mål, så nedbryder AI det til handlinger.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 30),
          TextField(
            controller: _controller,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "F.eks. 'Lær at spille guitar'",
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: vm.isLoading ? null : () {
                if (_controller.text.isNotEmpty) {
                  vm.generatePlanFromAI(_controller.text);
                  _controller.clear();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan genereret!")));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
              ),
              child: vm.isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("Generer Plan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
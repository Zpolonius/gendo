import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllere til felter
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _countryController = TextEditingController();

  bool _isLogin = true; // Styrer om vi viser Login eller Opret
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      if (_isLogin) {
        // --- LOG IND ---
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        // --- OPRET BRUGER MED PROFIL ---
        await authService.registerWithProfile(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          country: _countryController.text.trim(),
          company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        );
      }
    } catch (e) {
      setState(() {
        // Gør fejlbeskeder lidt mere læsbare
        String msg = e.toString();
        if (msg.contains('email-already-in-use')) {
          msg = "Denne e-mail er allerede i brug.";
        } else if (msg.contains('weak-password')) {msg = "Adgangskoden er for svag.";}
        else if (msg.contains('user-not-found')) {msg = "Bruger ikke fundet.";}
        else if (msg.contains('wrong-password')) {msg = "Forkert adgangskode.";}
        
        _errorMessage = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo eller Titel
                Image.asset('assets/gendo_logo.png', height: 80),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? "Velkommen tilbage" : "Opret Profil",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // --- FELTER DER KUN VISES VED OPRETTELSE ---
                if (!_isLogin) ...[
                   Row(
                    children: [
                      Expanded(child: _buildTextField(_firstNameController, "Fornavn", Icons.person)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_lastNameController, "Efternavn", null)),
                    ],
                   ),
                   const SizedBox(height: 16),
                   _buildTextField(_phoneController, "Telefon", Icons.phone, keyboardType: TextInputType.phone),
                   const SizedBox(height: 16),
                   _buildTextField(_countryController, "Land", Icons.public),
                   const SizedBox(height: 16),
                   _buildTextField(_companyController, "Firma (Valgfrit)", Icons.business, required: false),
                   const SizedBox(height: 16),
                ],

                // --- STANDARD FELTER ---
                _buildTextField(_emailController, "Email", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, "Adgangskode", Icons.lock, isPassword: true),
                
                const SizedBox(height: 24),
                
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isLogin ? 'Log ind' : 'Opret Profil', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    });
                  },
                  child: Text(_isLogin
                      ? 'Ny bruger? Opret profil her'
                      : 'Har du allerede en konto? Log ind'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData? icon, {bool isPassword = false, TextInputType? keyboardType, bool required = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: icon != null ? Icon(icon) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Feltet er påkrævet';
        }
        if (isPassword && value != null && value.length < 6) {
          return 'Min. 6 tegn';
        }
        return null;
      },
    );
  }
}
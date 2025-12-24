import 'package:flutter/material.dart';
import 'package:coaching/services/firebase_auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  String _role = 'teacher';
  String _gender = 'female'; // varsayılan değer

  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (val) => val!.isEmpty ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: _surnameController,
                  decoration: const InputDecoration(labelText: 'Surname'),
                  validator: (val) => val!.isEmpty ? 'Enter surname' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (val) => val!.isEmpty ? 'Enter email' : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (val) => val!.length < 6 ? '6+ chars required' : null,
                ),

                const SizedBox(height: 16),

                // Rol seçimi
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                  ],
                  onChanged: (val) => setState(() => _role = val!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),

                const SizedBox(height: 16),

                // Cinsiyet seçimi
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => _gender = val!),
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final user = await _authService.registerUser(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                        name: _nameController.text.trim(),
                        surname: _surnameController.text.trim(),
                        role: _role,
                        gender: _gender,
                      );

                      if (user != null) {
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/home');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Registration successful')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration failed')),
                        );
                      }
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

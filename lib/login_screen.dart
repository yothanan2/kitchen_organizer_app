// lib/login_screen.dart
// FINAL CORRECTED VERSION: Adds the kIsWeb platform check to prevent crashes on mobile.

import 'package:flutter/foundation.dart'; // <-- This import is necessary for the fix
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = true;

  late AnimationController _blinkAnimationController;
  late Animation<Color?> _blinkColorAnimation;

  @override
  void initState() {
    super.initState();
    _blinkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blinkColorAnimation = ColorTween(
      begin: Colors.red.shade900,
      end: Colors.grey.shade700,
    ).animate(_blinkAnimationController);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _blinkAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    await _performSignIn(_emailController.text, _passwordController.text);
  }

  Future<void> _performSignIn(String email, String password) async {
    setState(() { _isLoading = true; });

    try {
      // --- THIS IS THE ONLY CHANGE ---
      // This web-only setting is now wrapped in a platform check.
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      // --- END OF CHANGE ---

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Invalid email or password.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials. Please check your email and password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red.shade700),
        );
      }
    } catch (e) {
      if (mounted) {
        // This now checks for the specific error on mobile.
        if (e.toString().contains('setPersistence')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Error: Persistence is not supported on this platform.'), backgroundColor: Colors.red.shade700),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withAlpha(178),
              Colors.deepPurple.shade100,
              Colors.white,
            ],
            stops: const [0.1, 0.4, 0.9],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'UM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                      fontFamily: 'DistinctStyleSans',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kitchen Organizer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade800,
                      fontFamily: 'DistinctStyleSans',
                    ),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Log in to Mayhem',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter your email';
                              if (!value.contains('@')) return 'Please enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                            obscureText: true,
                            validator: (value) => (value == null || value.isEmpty) ? 'Please enter your password' : null,
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Remember Me'),
                            value: _rememberMe,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _rememberMe = newValue ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                            onPressed: _loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('Login'),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            child: const Text('Don\'t have an account? Register'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _blinkColorAnimation,
                    builder: (context, child) {
                      return Text(
                        "For Development Only - Quick Logins",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _blinkColorAnimation.value,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _emailController.text = "yothanan@gmail.com";
                            _passwordController.text = "12345678";
                            _loginUser();
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Quick Login (Admin)"),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _emailController.text = "yothanan.rov@gmail.com";
                            _passwordController.text = "12345678";
                            _loginUser();
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Quick Login (Kitchen Staff)"),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _emailController.text = "yothanan2@gmail.com";
                            _passwordController.text = "12345678";
                            _loginUser();
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Quick Login (Floor Staff)"),
                  ),
                  const SizedBox(height: 8),
                  // --- NEW: The Butcher quick-login button ---
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _emailController.text = "butcher@test.com";
                            _passwordController.text = "password123";
                            _loginUser();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade700, // A new color for the butcher
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Quick Login (Butcher Staff)"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
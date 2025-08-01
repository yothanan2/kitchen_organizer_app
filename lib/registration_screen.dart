import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _isLoading = false;
  bool _smsOptIn = false;
  String? _verificationId;
  bool _codeSent = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check for username uniqueness
      final usernameSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim().toLowerCase())
          .limit(1)
          .get();

      if (usernameSnapshot.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This username is already taken.'), backgroundColor: Colors.red),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? newUser = userCredential.user;

      if (newUser != null) {
        await newUser.sendEmailVerification();

        // If SMS opt-in is selected, initiate phone verification
        if (_smsOptIn && _phoneNumberController.text.isNotEmpty) {
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: _phoneNumberController.text.trim(),
            verificationCompleted: (PhoneAuthCredential credential) async {
              await newUser.linkWithCredential(credential);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number automatically verified!'), backgroundColor: Colors.green),
                );
              }
            },
            verificationFailed: (FirebaseAuthException e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Phone verification failed: ${e.message}'), backgroundColor: Colors.red),
                );
              }
              setState(() {
                _isLoading = false;
              });
            },
            codeSent: (String verificationId, int? resendToken) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SMS code sent to your phone.'), backgroundColor: Colors.blue),
                );
              }
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              setState(() {
                _verificationId = verificationId;
              });
            },
          );
        }

        // Now, create the user document in Firestore.
        await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
          'fullName': _fullNameController.text.trim(),
          'username': _usernameController.text.trim().toLowerCase(), // Store username
          'email': _emailController.text.trim(),
          'uid': newUser.uid,
          'role': 'Staff',
          'isApproved': false,
          'phoneNumber': _phoneNumberController.text.trim(), // Store phone number
          'smsOptIn': _smsOptIn, // Store SMS opt-in preference
          'createdOn': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPhoneNumberAndLink() async {
    setState(() {
      _isLoading = true;
    });
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text.trim(),
      );
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number verified and linked!'), backgroundColor: Colors.green),
        );
      }
      // Update Firestore with verified phone number and smsOptIn status
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
        'phoneNumber': _phoneNumberController.text.trim(),
        'smsOptIn': true,
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify phone number: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number (e.g., +11234567890)'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (_smsOptIn && (value == null || value.trim().isEmpty)) {
                    return 'Please enter your phone number to receive SMS notifications';
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                title: const Text('Receive daily progression via SMS'),
                value: _smsOptIn,
                onChanged: (bool? value) {
                  setState(() {
                    _smsOptIn = value ?? false;
                  });
                },
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _smsCodeController,
                  decoration: const InputDecoration(labelText: 'SMS Verification Code'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the SMS code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _verifyPhoneNumberAndLink,
                  child: const Text('Verify Phone Number'),
                ),
              ] else ...[
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _registerUser,
                  child: const Text('Register'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
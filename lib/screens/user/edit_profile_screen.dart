import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _isLoading = false;
  bool _smsOptIn = false;
  String? _verificationId;
  bool _codeSent = false;
  bool _isPhoneNumberChanged = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          _fullNameController.text = userData['fullName'] ?? '';
          _usernameController.text = userData['username'] ?? '';
          _phoneNumberController.text = userData['phoneNumber'] ?? '';
          _smsOptIn = userData['smsOptIn'] ?? false;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
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

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Check for username uniqueness if changed
        if (_usernameController.text.trim().toLowerCase() != (await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()).data()?['username']) {
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
        }

        // Check if phone number changed or SMS opt-in enabled
        String currentPhoneNumber = (await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()).data()?['phoneNumber'] ?? '';
        bool currentSmsOptIn = (await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()).data()?['smsOptIn'] ?? false;

        _isPhoneNumberChanged = _phoneNumberController.text.trim() != currentPhoneNumber;

        if ((_isPhoneNumberChanged || (_smsOptIn && !currentSmsOptIn)) && _phoneNumberController.text.isNotEmpty) {
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: _phoneNumberController.text.trim(),
            verificationCompleted: (PhoneAuthCredential credential) async {
              await currentUser.linkWithCredential(credential);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number automatically verified!'), backgroundColor: Colors.green),
                );
              }
              // Update Firestore immediately if auto-verified
              await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
                'fullName': _fullNameController.text.trim(),
                'username': _usernameController.text.trim().toLowerCase(),
                'phoneNumber': _phoneNumberController.text.trim(),
                'smsOptIn': _smsOptIn,
              });
              if (mounted) {
                Navigator.of(context).pop();
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
        } else {
          // No phone verification needed, just update Firestore
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'fullName': _fullNameController.text.trim(),
            'username': _usernameController.text.trim().toLowerCase(),
            'phoneNumber': _phoneNumberController.text.trim(),
            'smsOptIn': _smsOptIn,
          });
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e.code == 'email-already-in-use') {
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
      if (mounted) {
        Navigator.of(context).pop();
      }
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
    _phoneNumberController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
                  onPressed: _updateUserProfile,
                  child: const Text('Update Profile'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

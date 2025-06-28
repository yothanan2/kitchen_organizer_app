// lib/user_management_screen.dart
// MODIFIED: Corrected the import statement to use 'cloud_functions'.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // <-- THIS IS THE CORRECTED LINE

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  static const List<String> userRoles = ['Unassigned', 'Staff', 'Admin', 'Floor Staff', 'Butcher'];

  void _showEditUserDialog(BuildContext context, DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final String initialFullName = data['fullName'] ?? 'No Name';
    final String initialEmail = data['email'] ?? 'No Email';
    final bool initialIsApproved = data['isApproved'] ?? false;
    final String initialRole = data['role'] ?? 'Unassigned';

    bool currentIsApproved = initialIsApproved;
    String? currentSelectedRole = initialRole;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Edit User: $initialFullName"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Email: $initialEmail"),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text("Approved"),
                      value: currentIsApproved,
                      onChanged: (bool? newValue) {
                        setState(() {
                          currentIsApproved = newValue ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Assign Role:", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: currentSelectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      items: userRoles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          currentSelectedRole = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    setState(() { isLoading = true; });
                    try {
                      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('setUserRole');
                      await callable.call(<String, dynamic>{
                        'uid': userDoc.id,
                        'newRole': currentSelectedRole,
                      });

                      await FirebaseFirestore.instance.collection('users').doc(userDoc.id).update({
                        'isApproved': currentIsApproved,
                        'role': currentSelectedRole,
                      });

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User ${initialFullName} updated successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating user: ${e.toString()}'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (dialogContext.mounted) {
                        setState(() { isLoading = false; });
                      }
                    }
                  },
                  child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('fullName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data() as Map<String, dynamic>;
              final String fullName = data['fullName'] ?? 'No Name';
              final String email = data['email'] ?? 'No Email';
              final bool isApproved = data['isApproved'] ?? false;
              final String userRole = data['role'] ?? 'Unassigned';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(fullName),
                  subtitle: Text('$email - Role: $userRole'),
                  trailing: Icon(
                    isApproved ? Icons.check_circle : Icons.person_add_disabled,
                    color: isApproved ? Colors.green : Colors.red,
                    semanticLabel: isApproved ? 'Approved' : 'Not Approved',
                  ),
                  onTap: () => _showEditUserDialog(context, user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
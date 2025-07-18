// lib/user_management_screen.dart
// UPDATED: Added missing firebase_auth import.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- FIX: Added this line

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  static const List<String> userRoles = ['Unassigned', 'Staff', 'Admin', 'Floor Staff', 'Butcher'];

  // This is the updated dialog method
  void _showEditUserDialog(BuildContext context, DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final String initialFullName = data['fullName'] ?? 'No Name';
    final String initialEmail = data['email'] ?? 'No Email';
    final bool initialIsApproved = data['isApproved'] ?? false;
    final String initialRole = data['role'] ?? 'Unassigned';
    final String uid = userDoc.id;

    bool currentIsApproved = initialIsApproved;
    String? currentSelectedRole = initialRole;
    bool isLoading = false;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {

            Future<void> performDelete() async {
              final bool? confirmed = await showDialog<bool>(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  title: const Text("Confirm Deletion"),
                  content: Text("Are you sure you want to permanently delete the user '$initialFullName'? This action cannot be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(confirmContext).pop(false), child: const Text("Cancel")),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.of(confirmContext).pop(true),
                      child: const Text("Delete Permanently"),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              setState(() => isDeleting = true);

              try {
                final callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
                await callable.call({'uid': uid});

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User $initialFullName deleted successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting user: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (dialogContext.mounted) {
                  setState(() => isDeleting = false);
                }
              }
            }


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
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete User"),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: isLoading ? null : performDelete,
                  ),

                const Spacer(),

                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: isLoading || isDeleting ? null : () async {
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
                          SnackBar(content: Text('User $initialFullName updated successfully!'), backgroundColor: Colors.green),
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
        stream: FirebaseFirestore.instance.collection('users').orderBy('createdOn', descending: true).snapshots(),
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
          final currentUser = FirebaseAuth.instance.currentUser;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data() as Map<String, dynamic>;
              final String fullName = data['fullName'] ?? 'No Name';
              final String email = data['email'] ?? 'No Email';
              final bool isApproved = data['isApproved'] ?? false;
              final String userRole = data['role'] ?? 'Unassigned';

              final bool isCurrentUser = currentUser != null && currentUser.uid == user.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: isCurrentUser ? const Icon(Icons.account_circle, color: Colors.blue) : null,
                  title: Text(fullName),
                  subtitle: Text('$email - Role: $userRole'),
                  trailing: Icon(
                    isApproved ? Icons.check_circle : Icons.person_add_disabled,
                    color: isApproved ? Colors.green : Colors.red,
                    semanticLabel: isApproved ? 'Approved' : 'Not Approved',
                  ),
                  onTap: isCurrentUser
                      ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("You cannot edit or delete your own account from this screen."))
                    );
                  }
                      : () => _showEditUserDialog(context, user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
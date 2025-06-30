// lib/admin_home_screen.dart
// CORRECTED: Updated to work with family providers and fixed the icon error.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // <-- ADDED THIS IMPORT for date formatting

import 'dish_management_screen.dart';
import 'user_management_screen.dart';
import 'inventory_overview_screen.dart';
import 'shopping_list_screen.dart';
import 'floor_checklist_items_screen.dart';
import 'providers.dart';
import 'butcher_requisition_screen.dart';

// enum NoteAudience has been moved to providers.dart

class AdminHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onToggleView;

  const AdminHomeScreen({super.key, this.onToggleView});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  final _noteController = TextEditingController();
  bool _isSavingNote = false;
  NoteAudience _selectedAudience = NoteAudience.both;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentNote();
      }
    });
  }

  void _loadCurrentNote() {
    // UPDATED: Provide the current date to the family provider
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDoc = ref.read(dailyTodoListDocProvider(dateString)).value;
    if (dailyDoc != null && dailyDoc.exists) {
      final data = dailyDoc.data() as Map<String, dynamic>;
      final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
      _noteController.text = notesMap?['forKitchenStaff'] ?? notesMap?['forFloorStaff'] ?? notesMap?['forButcherStaff'] ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveDailyNote() async {
    setState(() { _isSavingNote = true; });
    final firestore = ref.read(firestoreProvider);
    // UPDATED: Provide the current date to the family provider
    final todayId = ref.read(todayDocIdProvider(DateTime.now()));
    final note = _noteController.text.trim();
    final Map<String, dynamic> noteData = {
      'forFloorStaff': _selectedAudience == NoteAudience.floor || _selectedAudience == NoteAudience.both ? note : '',
      'forKitchenStaff': _selectedAudience == NoteAudience.kitchen || _selectedAudience == NoteAudience.both ? note : '',
      'forButcherStaff': _selectedAudience == NoteAudience.butcher || _selectedAudience == NoteAudience.both ? note : '',
    };
    try {
      await firestore.collection('dailyTodoLists').doc(todayId).set(
        {'dailyNotes': noteData},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Daily note saved!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving note: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSavingNote = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // UPDATED: Provide the current date to the family provider
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.listen<AsyncValue<DocumentSnapshot>>(dailyTodoListDocProvider(dateString), (_, next) {
      final dailyDoc = next.value;
      if (dailyDoc != null && dailyDoc.exists) {
        final data = dailyDoc.data() as Map<String, dynamic>;
        final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
        final noteFromDb = notesMap?['forKitchenStaff'] ?? notesMap?['forFloorStaff'] ?? notesMap?['forButcherStaff'] ?? '';
        if (_noteController.text != noteFromDb) {
          _noteController.text = noteFromDb;
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) { // Corrected signature for PopInvokedCallback
        if (didPop) return;
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(child: const Text('No'), onPressed: () => Navigator.of(context).pop(false)),
              TextButton(child: const Text('Yes'), onPressed: () => Navigator.of(context).pop(true)),
            ],
          ),
        ).then((shouldPop) {
          if (shouldPop ?? false) { SystemNavigator.pop(); }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            if (widget.onToggleView != null)
              Tooltip(message: 'Switch to Staff View', child: IconButton(icon: const Icon(Icons.switch_account), onPressed: widget.onToggleView)),
            IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut(), tooltip: 'Logout'),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Daily Note", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SegmentedButton<NoteAudience>(
                      segments: const [
                        ButtonSegment(value: NoteAudience.floor, label: Text('Floor'), icon: Icon(Icons.deck_outlined)),
                        ButtonSegment(value: NoteAudience.kitchen, label: Text('Kitchen'), icon: Icon(Icons.soup_kitchen_outlined)),
                        ButtonSegment(value: NoteAudience.butcher, label: Text('Butcher'), icon: Icon(Icons.set_meal_outlined)),
                        ButtonSegment(value: NoteAudience.both, label: Text('All Staff'), icon: Icon(Icons.groups_outlined)),
                      ],
                      selected: {_selectedAudience},
                      onSelectionChanged: (Set<NoteAudience> newSelection) {
                        setState(() { _selectedAudience = newSelection.first; });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Enter today's note here",
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isSavingNote ? null : _saveDailyNote,
                      icon: _isSavingNote
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save Note'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Dish Management', icon: Icons.restaurant_menu_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DishManagementScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Inventory Management', icon: Icons.inventory_2_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InventoryOverviewScreen()))),
            const SizedBox(height: 12),
            // CORRECTED ICON: Replaced non-existent icon with a valid one
            _buildMenuButton(context, title: 'Butcher Requisition Form', icon: Icons.set_meal_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ButcherRequisitionScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Manage Floor Checklist', icon: Icons.deck_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FloorChecklistItemsScreen()))),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Manage Users', icon: Icons.people_outline, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Generate Shopping List', icon: Icons.shopping_cart_checkout_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(title),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        textStyle: const TextStyle(fontSize: 18),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}
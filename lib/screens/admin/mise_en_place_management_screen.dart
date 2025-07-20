import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchen_organizer_app/providers.dart';

class MiseEnPlaceManagementScreen extends ConsumerStatefulWidget {
  const MiseEnPlaceManagementScreen({super.key});

  @override
  ConsumerState<MiseEnPlaceManagementScreen> createState() => _MiseEnPlaceManagementScreenState();
}

class _MiseEnPlaceManagementScreenState extends ConsumerState<MiseEnPlaceManagementScreen> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final componentsStream = ref.watch(allComponentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mise en Place Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Components...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: componentsStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (components) {
          final filteredComponents = components.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final componentName = data['name']?.toString().toLowerCase() ?? '';
            return componentName.contains(_searchTerm);
          }).toList();

          if (filteredComponents.isEmpty) {
            return const Center(child: Text('No components found.'));
          }

          return ListView.builder(
            itemCount: filteredComponents.length,
            itemBuilder: (context, index) {
              final componentDoc = filteredComponents[index];
              return _buildComponentListItem(componentDoc);
            },
          );
        },
      ),
    );
  }

  Widget _buildComponentListItem(DocumentSnapshot componentDoc) {
    final data = componentDoc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Unnamed Component';
    final bool isGloballyActive = data['isGloballyActive'] ?? true; // Default to active

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(name),
        trailing: Switch(
          value: isGloballyActive,
          onChanged: (bool newValue) {
            FirebaseFirestore.instance
                .collection('components')
                .doc(componentDoc.id)
                .update({'isGloballyActive': newValue});
          },
        ),
      ),
    );
  }
}

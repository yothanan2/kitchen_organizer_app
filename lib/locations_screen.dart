import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final TextEditingController _locationController = TextEditingController();
  final CollectionReference _locationsCollection = FirebaseFirestore.instance.collection('locations');

  // Function to show a dialog for adding or editing a location
  void _showLocationDialog({DocumentSnapshot? locationDocument}) {
    if (locationDocument != null) {
      final data = locationDocument.data() as Map<String, dynamic>;
      _locationController.text = data['name'] ?? '';
    } else {
      _locationController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(locationDocument == null ? 'Add New Location' : 'Edit Location'),
          content: TextField(
            controller: _locationController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter location name (e.g., Dry Storage)"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final locationName = _locationController.text.trim();
                if (locationName.isEmpty) return;

                // Fool-proof check to prevent duplicate location names
                final querySnapshot = await _locationsCollection.where('name', isEqualTo: locationName).limit(1).get();
                if (querySnapshot.docs.isNotEmpty && (locationDocument == null || querySnapshot.docs.first.id != locationDocument.id)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('A location with the name "$locationName" already exists.')),
                    );
                  }
                  return;
                }

                if (locationDocument == null) {
                  _locationsCollection.add({'name': locationName});
                } else {
                  _locationsCollection.doc(locationDocument.id).update({'name': locationName});
                }
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to show a confirmation dialog before deleting
  Future<void> _showDeleteConfirmDialog(BuildContext context, String docId, String locationName) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the location "$locationName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                _locationsCollection.doc(docId).delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Locations'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _locationsCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No locations found. Add one!'));
          }

          final locations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              final data = location.data() as Map<String, dynamic>;
              final locationName = data['name'] ?? 'Unnamed Location';

              return ListTile(
                title: Text(locationName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showLocationDialog(locationDocument: location),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmDialog(context, location.id, locationName),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLocationDialog(),
        tooltip: 'Add Location',
        child: const Icon(Icons.add),
      ),
    );
  }
}

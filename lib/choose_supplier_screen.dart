import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_overview_screen.dart';
import 'providers.dart'; // Import our central providers file

// The screen is now a stateless ConsumerWidget.
class ChooseSupplierScreen extends ConsumerWidget {
  const ChooseSupplierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the allSuppliersProvider to get the list of suppliers.
    final suppliersAsync = ref.watch(allSuppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Supplier'),
      ),
      // We use .when() to handle the loading/error/data states gracefully.
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (supplierDocs) {
          if (supplierDocs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No suppliers have been created yet. Please add one from the Inventory Overview screen menu.'),
              ),
            );
          }
          return ListView.builder(
            itemCount: supplierDocs.length,
            itemBuilder: (context, index) {
              final supplierDoc = supplierDocs[index];
              final supplierName = (supplierDoc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed Supplier';

              return ListTile(
                title: Text(supplierName),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // MODIFIED: We now navigate directly to the InventoryOverviewScreen.
                  // It no longer needs any parameters.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const InventoryOverviewScreen(),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

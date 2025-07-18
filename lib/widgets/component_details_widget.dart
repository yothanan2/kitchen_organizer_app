import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';
import 'package:kitchen_organizer_app/models/models.dart';

class ComponentDetailsWidget extends ConsumerWidget {
  final DocumentReference componentRef;

  const ComponentDetailsWidget({super.key, required this.componentRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A provider to fetch the component document
    final componentProvider = FutureProvider.autoDispose<DocumentSnapshot>((ref) async {
      return componentRef.get();
    });

    return ref.watch(componentProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading component: $err')),
          data: (componentDoc) {
            if (!componentDoc.exists) {
              return const Center(child: Text('Component data not found.'));
            }
            final componentData = componentDoc.data() as Map<String, dynamic>;
            final dish = Dish.fromFirestore(componentData, componentDoc.id);

            // A provider to fetch the ingredients subcollection
            final ingredientsProvider = FutureProvider.autoDispose<QuerySnapshot>((ref) async {
              return componentRef.collection('ingredients').get();
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dish.recipeInstructions.isNotEmpty) ...[
                  const Text('Recipe:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(dish.recipeInstructions),
                  const SizedBox(height: 16),
                ],
                const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ref.watch(ingredientsProvider).when(
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) => Text('Error loading ingredients: $err'),
                      data: (ingredientsSnapshot) {
                        if (ingredientsSnapshot.docs.isEmpty) {
                          return const Text('No ingredients listed.');
                        }
                        return Column(
                          children: ingredientsSnapshot.docs.map((doc) {
                            final ingredient = Ingredient.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.fiber_manual_record, size: 10),
                              title: FirestoreNameWidget(
                                docRef: ingredient.inventoryItemRef,
                                builder: (context, name) => Text(name),
                              ),
                              subtitle: ingredient.type == IngredientType.quantified
                                  ? FirestoreNameWidget(
                                      docRef: ingredient.unitRef,
                                      builder: (context, unitName) => Text('${ingredient.quantity} $unitName'),
                                    )
                                  : const Text('On-Hand'),
                            );
                          }).toList(),
                        );
                      },
                    ),
              ],
            );
          },
        );
  }
}

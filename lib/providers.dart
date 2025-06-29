// lib/providers.dart
// V11: Added logic and providers for the Task Completion analytics report.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';

// ==== Enums moved here for global access ====
enum NoteAudience { floor, kitchen, butcher, both }

// ==== Core Firebase Providers ====
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// ==== Auth-Related Providers ====
@immutable
class AppUser {
  final String uid;
  final String? email, fullName;
  final String role;
  final bool isApproved, isEmailVerified;
  const AppUser({ required this.uid, this.email, this.fullName, required this.role, required this.isApproved, required this.isEmailVerified });
}

final appUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncMap((user) async {
    if (user == null) return null;
    await user.reload();
    final refreshedUser = ref.read(firebaseAuthProvider).currentUser;
    if (refreshedUser == null) return null;
    final firestore = ref.read(firestoreProvider);
    final userDocRef = firestore.collection('users').doc(refreshedUser.uid);
    final doc = await userDocRef.get();
    if (!doc.exists) {
      final defaultName = refreshedUser.displayName ?? refreshedUser.email ?? 'New User';
      final defaultUserData = {
        'email': refreshedUser.email,
        'fullName': defaultName,
        'role': 'Unassigned',
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await userDocRef.set(defaultUserData);
      return AppUser(uid: refreshedUser.uid, email: refreshedUser.email, fullName: defaultName, role: 'Unassigned', isApproved: false, isEmailVerified: refreshedUser.emailVerified);
    }
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(uid: refreshedUser.uid, email: refreshedUser.email, fullName: data['fullName'], role: data['role'] ?? 'Unassigned', isApproved: data['isApproved'] ?? false, isEmailVerified: refreshedUser.emailVerified);
  });
});

final unapprovedUsersCountProvider = StreamProvider<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final lowStockItemsCountProvider = StreamProvider<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventoryItems')
      .snapshots()
      .map((snapshot) {
    int count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final num quantity = data['quantityOnHand'] ?? 0;
      final num minStock = data['minStockLevel'] ?? 0;
      if (quantity <= minStock) {
        count++;
      }
    }
    return count;
  });
});

// ==== Daily Note Controller ====
@immutable
class DailyNoteState {
  final bool isSaving;
  final NoteAudience selectedAudience;
  const DailyNoteState({ this.isSaving = false, this.selectedAudience = NoteAudience.both });
  DailyNoteState copyWith({ bool? isSaving, NoteAudience? selectedAudience, }) {
    return DailyNoteState(isSaving: isSaving ?? this.isSaving, selectedAudience: selectedAudience ?? this.selectedAudience);
  }
}
class DailyNoteController extends StateNotifier<DailyNoteState> {
  DailyNoteController(this.ref) : super(const DailyNoteState());
  final Ref ref;

  void setAudience(NoteAudience audience) {
    state = state.copyWith(selectedAudience: audience);
  }

  Future<String?> saveNote(String note) async {
    state = state.copyWith(isSaving: true);
    final firestore = ref.read(firestoreProvider);
    final todayId = ref.read(todayDocIdProvider(DateTime.now()));
    final noteData = {
      'forFloorStaff': state.selectedAudience == NoteAudience.floor || state.selectedAudience == NoteAudience.both ? note : '',
      'forKitchenStaff': state.selectedAudience == NoteAudience.kitchen || state.selectedAudience == NoteAudience.both ? note : '',
      'forButcherStaff': state.selectedAudience == NoteAudience.butcher || state.selectedAudience == NoteAudience.both ? note : '',
    };
    try {
      await firestore.collection('dailyTodoLists').doc(todayId).set({'dailyNotes': noteData}, SetOptions(merge: true));
      state = state.copyWith(isSaving: false);
      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return e.toString();
    }
  }
}
final dailyNoteControllerProvider = StateNotifierProvider.autoDispose<DailyNoteController, DailyNoteState>((ref) => DailyNoteController(ref));

// ==== Date & Task Providers ====
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final todayDocIdProvider = Provider.family<String, DateTime>((ref, date) => DateFormat('yyyy-MM-dd').format(date));
final dailyTodoListDocProvider = StreamProvider.family<DocumentSnapshot, String>((ref, date) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('dailyTodoLists').doc(date).snapshots();
});
@immutable
class TaskListParams {
  final String collectionPath;
  final bool isCompleted;
  final String date;
  const TaskListParams({ required this.collectionPath, required this.isCompleted, required this.date });
  @override
  bool operator ==(Object other) => identical(this, other) || other is TaskListParams && runtimeType == other.runtimeType && collectionPath == other.collectionPath && isCompleted == other.isCompleted && date == other.date;
  @override
  int get hashCode => collectionPath.hashCode ^ isCompleted.hashCode ^ date.hashCode;
}
final tasksStreamProvider = StreamProvider.family<QuerySnapshot, TaskListParams>((ref, params) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('dailyTodoLists').doc(params.date).collection(params.collectionPath).where('isCompleted', isEqualTo: params.isCompleted).orderBy('createdAt').snapshots();
});

// ==== Weather Providers ====
@immutable
class WeatherData {
  final double currentTemp, maxTemp, minTemp;
  final String weatherDescription, weatherIcon;
  final String dailyWeatherDescription, dailyWeatherIcon;
  final List<dynamic> hourlyTime, hourlyWeatherCode;

  const WeatherData({
    required this.currentTemp, required this.maxTemp, required this.minTemp,
    required this.weatherDescription, required this.weatherIcon,
    required this.dailyWeatherDescription, required this.dailyWeatherIcon,
    required this.hourlyTime, required this.hourlyWeatherCode,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final currentWeatherInfo = _mapWeatherCode(current['weather_code'] as int);
    final dailyWeatherInfo = _mapWeatherCode(daily['weather_code'][0] as int);
    return WeatherData(
      currentTemp: (current['temperature_2m'] as num).toDouble(),
      maxTemp: (daily['temperature_2m_max'][0] as num).toDouble(),
      minTemp: (daily['temperature_2m_min'][0] as num).toDouble(),
      weatherDescription: currentWeatherInfo.$1, weatherIcon: currentWeatherInfo.$2,
      dailyWeatherDescription: dailyWeatherInfo.$1, dailyWeatherIcon: dailyWeatherInfo.$2,
      hourlyTime: hourly['time'] as List<dynamic>,
      hourlyWeatherCode: hourly['weather_code'] as List<dynamic>,
    );
  }
  static (String, String) _mapWeatherCode(int code) {
    switch (code) { case 0: return ('Clear sky', '☀️'); case 1: return ('Mainly clear', '🌤️'); case 2: return ('Partly cloudy', '⛅'); case 3: return ('Overcast', '☁️'); case 45: case 48: return ('Fog', '🌫️'); case 51: case 53: case 55: return ('Drizzle', '🌦️'); case 61: case 63: case 65: return ('Rain', '🌧️'); case 66: case 67: return ('Freezing Rain', '🌨️'); case 71: case 73: case 75: return ('Snow fall', '❄️'); case 80: case 81: case 82: return ('Rain showers', '🌦️'); case 85: case 86: return ('Snow showers', '🌨️'); case 95: return ('Thunderstorm', '⛈️'); default: return ('Unknown', '🤷'); }
  }
  String? findFirstPrecipitation() {
    final now = DateTime.now();
    for (int i = 0; i < hourlyTime.length; i++) {
      try {
        final time = DateTime.parse(hourlyTime[i]);
        if (time.isAfter(now)) {
          final code = hourlyWeatherCode[i] as int;
          if ((code >= 51 && code <= 86) || code == 95) {
            final weatherInfo = _mapWeatherCode(code);
            final eventType = weatherInfo.$1.split(' ').first;
            final formattedTime = DateFormat('ha').format(time).toLowerCase();
            return '$eventType starting around $formattedTime';
          }
        }
      } catch (e) { /* Ignore parsing errors */ }
    }
    return null;
  }
}
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=55.68&longitude=12.59&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&hourly=weather_code&timezone=auto');
  final response = await http.get(url);
  if (response.statusCode == 200) return WeatherData.fromJson(json.decode(response.body));
  throw Exception('Failed to load weather data');
});

// ==== Map Providers for Helper Widgets ====
final unitsMapProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final snapshot = await ref.watch(firestoreProvider).collection('units').get();
  return {for (var doc in snapshot.docs) doc.id: (doc.data())['name'] ?? 'N/A'};
});
final suppliersMapProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final snapshot = await ref.watch(firestoreProvider).collection('suppliers').get();
  return {for (var doc in snapshot.docs) doc.id: (doc.data())['name'] ?? 'N/A'};
});
final categoriesMapProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final snapshot = await ref.watch(firestoreProvider).collection('categories').get();
  return {for (var doc in snapshot.docs) doc.id: (doc.data())['name'] ?? 'Uncategorized'};
});
final locationsMapProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final snapshot = await ref.watch(firestoreProvider).collection('locations').get();
  return {for (var doc in snapshot.docs) doc.id: (doc.data())['name'] ?? 'N/A'};
});

// ==== Dropdown Data Providers ====
final unitsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) => ref.watch(firestoreProvider).collection('units').orderBy('name').snapshots());
final categoriesStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) => ref.watch(firestoreProvider).collection('categories').orderBy('name').snapshots());
final suppliersStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) => ref.watch(firestoreProvider).collection('suppliers').orderBy('name').snapshots());
final locationsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) => ref.watch(firestoreProvider).collection('locations').orderBy('name').snapshots());

// ==== Add/Edit Inventory Item Providers ====
final inventoryItemProvider = FutureProvider.autoDispose.family<DocumentSnapshot?, String>((ref, docId) async {
  if (docId.isEmpty) return null;
  return ref.watch(firestoreProvider).collection('inventoryItems').doc(docId).get();
});
@immutable
class ItemFormState {
  final bool isLoading;
  final bool isButcherItem;
  const ItemFormState({this.isLoading = false, this.isButcherItem = false});
  ItemFormState copyWith({bool? isLoading, bool? isButcherItem}) => ItemFormState(isLoading: isLoading ?? this.isLoading, isButcherItem: isButcherItem ?? this.isButcherItem);
}
class ItemFormController extends StateNotifier<ItemFormState> {
  ItemFormController(this.ref) : super(const ItemFormState());
  final Ref ref;
  void setInitialState(Map<String, dynamic> data) => state = state.copyWith(isButcherItem: data['isButcherItem'] ?? false);
  void updateIsButcherItem(bool value) => state = state.copyWith(isButcherItem: value);
  Future<String?> saveItem({required String? existingDocId, required Map<String, dynamic> itemData}) async {
    state = state.copyWith(isLoading: true);
    final firestore = ref.read(firestoreProvider);
    final fullData = {...itemData, 'isButcherItem': state.isButcherItem, 'lastUpdated': FieldValue.serverTimestamp()};
    try {
      if (existingDocId != null && existingDocId.isNotEmpty) {
        await firestore.collection('inventoryItems').doc(existingDocId).update(fullData);
      } else {
        await firestore.collection('inventoryItems').add({...fullData, 'quantityOnHand': 0});
      }
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return 'Failed to save item: $e';
    }
  }
}
final itemFormControllerProvider = StateNotifierProvider.autoDispose<ItemFormController, ItemFormState>((ref) => ItemFormController(ref));

// ==== Butcher Requisition Provider ====
final butcherRequestableItemsProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('inventoryItems').where('isButcherItem', isEqualTo: true).orderBy('itemName').snapshots();
});

// ==== Floor Checklist Providers ====
final floorChecklistItemsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  return ref.watch(firestoreProvider).collection('floor_checklist_items').orderBy('order').snapshots().map((snapshot) => snapshot.docs);
});
final dailyFloorChecklistProvider = StreamProvider.autoDispose<DocumentSnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return firestore.collection('dailyFloorChecklists').doc(today).snapshots();
});
class FloorChecklistController {
  final Ref ref;
  FloorChecklistController(this.ref);
  Future<void> toggleItem(String itemName, bool isChecked) async {
    final firestore = ref.read(firestoreProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = firestore.collection('dailyFloorChecklists').doc(today);
    try {
      await docRef.set({itemName: isChecked}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating checklist: $e");
    }
  }
}
final floorChecklistControllerProvider = Provider.autoDispose<FloorChecklistController>((ref) => FloorChecklistController(ref));

// ==== Preparation & Planning Providers ====
final dishesProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) => ref.watch(firestoreProvider).collection('dishes').orderBy('dishName').snapshots());
final prepTasksProvider = FutureProvider.autoDispose.family<QuerySnapshot, DocumentReference>((ref, dishRef) => dishRef.collection('prepTasks').get());
@immutable
class PreparationState {
  final Map<String, bool> selectedTasks;
  final Map<String, String> taskNotes;
  final bool isLoading;
  const PreparationState({ this.selectedTasks = const {}, this.taskNotes = const {}, this.isLoading = false });
  PreparationState copyWith({ Map<String, bool>? selectedTasks, Map<String, String>? taskNotes, bool? isLoading }) => PreparationState(selectedTasks: selectedTasks ?? this.selectedTasks, taskNotes: taskNotes ?? this.taskNotes, isLoading: isLoading ?? this.isLoading);
}
class PreparationController extends StateNotifier<PreparationState> {
  PreparationController(this.ref) : super(const PreparationState());
  final Ref ref;
  void toggleTask(String taskId, bool isSelected) { state = state.copyWith(selectedTasks: {...state.selectedTasks, taskId: isSelected}); }
  void updateNote(String taskId, String note) { state = state.copyWith(taskNotes: {...state.taskNotes, taskId: note}); }
  Future<String?> generateLists(DateTime forDate) async {
    state = state.copyWith(isLoading: true);
    final firestore = ref.read(firestoreProvider);
    final dateString = DateFormat('yyyy-MM-dd').format(forDate);
    final dailyListRef = firestore.collection('dailyTodoLists').doc(dateString);
    final batch = firestore.batch();
    try {
      final dishesSnapshot = await firestore.collection('dishes').get();
      final allTasksByDish = <String, QuerySnapshot>{};
      for (final dishDoc in dishesSnapshot.docs) {
        allTasksByDish[dishDoc.id] = await dishDoc.reference.collection('prepTasks').get();
      }
      final existingTasksSnapshot = await dailyListRef.collection('prepTasks').limit(1).get();
      if (existingTasksSnapshot.docs.isNotEmpty) {
        state = state.copyWith(isLoading: false);
        return 'A prep list for this date already exists. Please clear it manually before generating a new one.';
      }
      batch.set(dailyListRef, {'createdAt': FieldValue.serverTimestamp(), 'date': dateString}, SetOptions(merge: true));
      for (final entry in state.selectedTasks.entries) {
        final taskId = entry.key;
        final isSelected = entry.value;
        if (isSelected) {
          String? dishName;
          DocumentSnapshot? taskDoc;
          for (final dishDoc in dishesSnapshot.docs) {
            final taskSnapshot = allTasksByDish[dishDoc.id];
            final foundTask = taskSnapshot?.docs.firstWhereOrNull((doc) => doc.id == taskId);
            if (foundTask != null) {
              dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'];
              taskDoc = foundTask;
              break;
            }
          }
          if (taskDoc != null) {
            final taskData = taskDoc.data() as Map<String, dynamic>;
            final newTaskRef = dailyListRef.collection('prepTasks').doc();
            batch.set(newTaskRef, {'taskName': taskData['taskName'], 'dishName': dishName ?? 'Unknown Dish', 'note': state.taskNotes[taskId] ?? '', 'isCompleted': false, 'createdAt': FieldValue.serverTimestamp()});
          }
        }
      }
      await batch.commit();
      state = const PreparationState();
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return 'Failed to generate lists: $e';
    } finally {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}
final preparationControllerProvider = StateNotifierProvider.autoDispose<PreparationController, PreparationState>((ref) => PreparationController(ref));

// ==== General App Data Providers ====
final allSuppliersProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) => ref.watch(firestoreProvider).collection('suppliers').orderBy('name').snapshots().map((s) => s.docs));
final itemsBySupplierProvider = StreamProvider.autoDispose.family<List<QueryDocumentSnapshot>, String>((ref, supplierId) {
  final firestore = ref.watch(firestoreProvider);
  final supplierRef = firestore.collection('suppliers').doc(supplierId);
  return firestore.collection('inventoryItems').where('supplier', isEqualTo: supplierRef).orderBy('itemName').snapshots().map((s) => s.docs);
});
final inventoryGroupsProvider = StreamProvider.autoDispose<Map<String, List<DocumentSnapshot>>>((ref) async* {
  final firestore = ref.watch(firestoreProvider);
  final locationsSnapshot = await firestore.collection('locations').get();
  final locationMap = {for (var doc in locationsSnapshot.docs) doc.id: (doc.data())['name'] ?? 'Uncategorized'};
  locationMap[''] = 'Uncategorized';
  final stream = firestore.collection('inventoryItems').orderBy('itemName').snapshots();
  await for (var snapshot in stream) {
    yield groupBy(snapshot.docs, (doc) => locationMap[(doc.data() as Map<String, dynamic>)['location']?.id] ?? 'Uncategorized');
  }
});
final todaysListExistsProvider = StreamProvider.autoDispose.family<bool, String>((ref, date) => ref.watch(firestoreProvider).collection('dailyTodoLists').doc(date).collection('prepTasks').limit(1).snapshots().map((s) => s.docs.isNotEmpty));
final showCompletedTasksProvider = StateProvider<bool>((ref) => false);
final newBarRequestsProvider = StreamProvider.autoDispose<List<DocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final currentStaffDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return firestore.collection('dailyTodoLists').doc(currentStaffDate).collection('barRequests').where('isCompleted', isEqualTo: false).snapshots().map((snapshot) => snapshot.docs);
});
final tomorrowsFloorStaffPrepTasksProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final tomorrowFormattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
  return firestore.collection('dailyTodoLists').doc(tomorrowFormattedDate).collection('prepTasks').where('category', isEqualTo: 'Floor Staff Report').snapshots().map((snapshot) => snapshot.docs.map((doc) => doc['originalFloorChecklistItemId'] as String).toSet());
});

// ==== Analytics Providers ==== // <-- NEW SECTION

@immutable
class AnalyzedIngredient {
  final String name;
  final String unit;
  final num totalQuantity;
  const AnalyzedIngredient({ required this.name, required this.unit, required this.totalQuantity });
}

@immutable
class TaskChampion {
  final String name;
  final int taskCount;
  const TaskChampion({ required this.name, required this.taskCount });
}

class AnalyticsController {
  final Ref ref;
  AnalyticsController(this.ref);

  Future<List<AnalyzedIngredient>> getMostUsedIngredients({ required DateTime startDate, required DateTime endDate, }) async {
    final firestore = ref.read(firestoreProvider);
    final unitsMap = await ref.read(unitsMapProvider.future);
    final inventoryItemsMap = <String, String>{};
    final usageMap = <String, Map<String, num>>{};
    final dailyListsSnapshot = await firestore.collection('dailyTodoLists').where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate)).where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate)).get();
    for (final dailyDoc in dailyListsSnapshot.docs) {
      final requisitionsSnapshot = await dailyDoc.reference.collection('stockRequisitions').get();
      for (final reqDoc in requisitionsSnapshot.docs) {
        final data = reqDoc.data();
        final itemRef = data['inventoryItemRef'] as DocumentReference?;
        final unitRef = data['unitRef'] as DocumentReference?;
        final quantity = data['quantity'] as num?;
        if (itemRef != null && unitRef != null && quantity != null && quantity > 0) {
          final itemId = itemRef.id;
          final unitId = unitRef.id;
          usageMap.putIfAbsent(itemId, () => {});
          usageMap[itemId]!.putIfAbsent(unitId, () => 0);
          usageMap[itemId]![unitId] = usageMap[itemId]![unitId]! + quantity;
        }
      }
    }
    final result = <AnalyzedIngredient>[];
    for (final entry in usageMap.entries) {
      final itemId = entry.key;
      final usageByUnit = entry.value;
      if (!inventoryItemsMap.containsKey(itemId)) {
        final itemDoc = await firestore.collection('inventoryItems').doc(itemId).get();
        inventoryItemsMap[itemId] = (itemDoc.data() as Map<String, dynamic>)['itemName'] ?? 'Unknown Item';
      }
      final itemName = inventoryItemsMap[itemId]!;
      for (final unitEntry in usageByUnit.entries) {
        final unitId = unitEntry.key;
        final totalQuantity = unitEntry.value;
        final unitName = unitsMap[unitId] ?? 'Unknown Unit';
        result.add(AnalyzedIngredient(name: itemName, unit: unitName, totalQuantity: totalQuantity));
      }
    }
    result.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    return result;
  }

  Future<List<TaskChampion>> getTaskCompletionStats({ required DateTime startDate, required DateTime endDate, }) async {
    final firestore = ref.read(firestoreProvider);
    final completionCounts = <String, int>{};
    final dailyListsSnapshot = await firestore.collection('dailyTodoLists').where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate)).where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate)).get();

    for (final dailyDoc in dailyListsSnapshot.docs) {
      final prepTasksSnapshot = await dailyDoc.reference.collection('prepTasks').where('isCompleted', isEqualTo: true).get();
      final stockReqsSnapshot = await dailyDoc.reference.collection('stockRequisitions').where('isCompleted', isEqualTo: true).get();
      final allTasks = [...prepTasksSnapshot.docs, ...stockReqsSnapshot.docs];

      for (final taskDoc in allTasks) {
        final data = taskDoc.data();
        final completedBy = data['completedBy'] as String?;
        if (completedBy != null && completedBy.isNotEmpty) {
          completionCounts.update(completedBy, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }

    final result = completionCounts.entries.map((entry) => TaskChampion(name: entry.key, taskCount: entry.value)).toList();
    result.sort((a, b) => b.taskCount.compareTo(a.taskCount));
    return result;
  }
}

final analyticsControllerProvider = Provider<AnalyticsController>((ref) => AnalyticsController(ref));

final mostUsedIngredientsProvider = FutureProvider.autoDispose.family<List<AnalyzedIngredient>, DateTimeRange>((ref, dateRange) {
  final controller = ref.watch(analyticsControllerProvider);
  return controller.getMostUsedIngredients(startDate: dateRange.start, endDate: dateRange.end);
});

final taskCompletionProvider = FutureProvider.autoDispose.family<List<TaskChampion>, DateTimeRange>((ref, dateRange) {
  final controller = ref.watch(analyticsControllerProvider);
  return controller.getTaskCompletionStats(startDate: dateRange.start, endDate: dateRange.end);
});
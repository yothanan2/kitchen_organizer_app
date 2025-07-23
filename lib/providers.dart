// lib/providers.dart
// FINAL FIX: Corrected the status query in requisitionHistoryProvider to 'received'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kitchen_organizer_app/controllers/next_day_task_controller.dart';
import 'package:kitchen_organizer_app/models/models.dart';

// ==== Enums ====
enum NoteAudience { floor, kitchen, butcher, both }

// ==== Core Firebase Providers ====
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// ==== Next Day Task Providers ====
final nextDayTaskControllerProvider = Provider<NextDayTaskController>((ref) {
  return NextDayTaskController(ref.watch(firestoreProvider));
});

final nextDayTasksProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowDateString = DateFormat('yyyy-MM-dd').format(tomorrow);

  return firestore
      .collection('nextDayTasks')
      .doc(tomorrowDateString)
      .collection('tasks')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
});

final flaggedTasksForTodayCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return firestore
      .collection('nextDayTasks')
      .doc(today)
      .collection('tasks')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});



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

final unapprovedUsersCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final lowStockItemsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventoryItems')
      .where('isButcherItem', isEqualTo: false)
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

final lowStockItemsProvider = StreamProvider.autoDispose<List<InventoryItem>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventoryItems')
      .where('isButcherItem', isEqualTo: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id))
        .where((item) => item.quantityOnHand <= item.minStockLevel)
        .toList();
  });
});

// ==== Daily Note Controller ====
@immutable
class DailyNoteState {
  final bool isSaving;
  final NoteAudience selectedAudience;
  final String noteText;

  const DailyNoteState({
    this.isSaving = false,
    this.selectedAudience = NoteAudience.both,
    this.noteText = '',
  });

  DailyNoteState copyWith({ bool? isSaving, NoteAudience? selectedAudience, String? noteText, }) {
    return DailyNoteState(
      isSaving: isSaving ?? this.isSaving,
      selectedAudience: selectedAudience ?? this.selectedAudience,
      noteText: noteText ?? this.noteText,
    );
  }
}

class DailyNoteController extends StateNotifier<DailyNoteState> {
  DailyNoteController(this.ref) : super(const DailyNoteState()) {
    _loadNoteForAudience(state.selectedAudience);
  }
  final Ref ref;

  final Map<NoteAudience, String> _noteCache = {};

  Future<void> _loadNoteForAudience(NoteAudience audience) async {
    final firestore = ref.read(firestoreProvider);
    final todayId = ref.read(todayDocIdProvider(DateTime.now()));
    final doc = await firestore.collection('dailyTodoLists').doc(todayId).get();

    if (doc.exists) {
      final data = doc.data() ?? {};
      final notesMap = data['dailyNotes'] as Map<String, dynamic>? ?? {};
      _noteCache[NoteAudience.floor] = notesMap['forFloorStaff'] ?? '';
      _noteCache[NoteAudience.kitchen] = notesMap['forKitchenStaff'] ?? '';
      _noteCache[NoteAudience.butcher] = notesMap['forButcherStaff'] ?? '';
      _noteCache[NoteAudience.both] = notesMap['forKitchenStaff'] ?? '';
    }
    if (mounted) {
      state = state.copyWith(noteText: _noteCache[audience] ?? '');
    }
  }

  void setAudience(NoteAudience audience) {
    state = state.copyWith(selectedAudience: audience, noteText: _noteCache[audience] ?? '');
  }

  void updateNoteText(String text) {
    state = state.copyWith(noteText: text);
  }

  Future<String?> saveNote() async {
    state = state.copyWith(isSaving: true);
    final firestore = ref.read(firestoreProvider);
    final todayId = ref.read(todayDocIdProvider(DateTime.now()));
    final note = state.noteText;
    final docRef = firestore.collection('dailyTodoLists').doc(todayId);

    try {
      final doc = await docRef.get();
      final Map<String, dynamic> notesMap = (doc.exists && doc.data()?['dailyNotes'] != null)
          ? Map<String, dynamic>.from(doc.data()!['dailyNotes'])
          : {};

      if (state.selectedAudience == NoteAudience.floor) {
        notesMap['forFloorStaff'] = note;
      } else if (state.selectedAudience == NoteAudience.kitchen) {
        notesMap['forKitchenStaff'] = note;
      } else if (state.selectedAudience == NoteAudience.butcher) {
        notesMap['forButcherStaff'] = note;
      } else { // NoteAudience.both
        notesMap['forFloorStaff'] = note;
        notesMap['forKitchenStaff'] = note;
        notesMap['forButcherStaff'] = note;
      }

      await docRef.set({'dailyNotes': notesMap}, SetOptions(merge: true));

      _noteCache[state.selectedAudience] = '';
      if (state.selectedAudience == NoteAudience.both) {
        _noteCache[NoteAudience.floor] = '';
        _noteCache[NoteAudience.kitchen] = '';
        _noteCache[NoteAudience.butcher] = '';
      }
      state = state.copyWith(isSaving: false, noteText: '');

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
  final bool? isCompleted; // Make optional
  final String date;
  const TaskListParams({ required this.collectionPath, this.isCompleted, required this.date });
  @override
  bool operator ==(Object other) => identical(this, other) || other is TaskListParams && runtimeType == other.runtimeType && collectionPath == other.collectionPath && isCompleted == other.isCompleted && date == other.date;
  @override
  int get hashCode => collectionPath.hashCode ^ isCompleted.hashCode ^ date.hashCode;
}
final tasksStreamProvider = StreamProvider.family<QuerySnapshot, TaskListParams>((ref, params) {
  final firestore = ref.watch(firestoreProvider);
  Query query = firestore.collection('dailyTodoLists').doc(params.date).collection(params.collectionPath);
  if (params.isCompleted != null) {
    query = query.where('isCompleted', isEqualTo: params.isCompleted);
  }
  return query.orderBy('createdAt').snapshots();
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
final inventoryItemProvider = FutureProvider.autoDispose.family<InventoryItem?, String>((ref, docId) async {
  if (docId.isEmpty) return null;
  final doc = await ref.watch(firestoreProvider).collection('inventoryItems').doc(docId).get();
  if (doc.exists) {
    return InventoryItem.fromFirestore(doc.data()!, doc.id);
  }
  return null;
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
        await firestore.collection('inventoryItems').add(fullData);
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
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('inventoryItems').where('isButcherItem', isEqualTo: true).orderBy('itemName').snapshots();
});

// ==== Floor Checklist Providers ====
final floorChecklistItemsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  return ref.watch(firestoreProvider)
      .collection('floor_checklist_items')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs);
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
  final Map<String, TextEditingController> quantityControllers;
  final Map<String, String?> selectedUnits;
  final bool isLoading;

  const PreparationState({
    this.selectedTasks = const {},
    this.taskNotes = const {},
    this.quantityControllers = const {},
    this.selectedUnits = const {},
    this.isLoading = false,
  });

  PreparationState copyWith({
    Map<String, bool>? selectedTasks,
    Map<String, String>? taskNotes,
    Map<String, TextEditingController>? quantityControllers,
    Map<String, String?>? selectedUnits,
    bool? isLoading,
  }) {
    return PreparationState(
      selectedTasks: selectedTasks ?? this.selectedTasks,
      taskNotes: taskNotes ?? this.taskNotes,
      quantityControllers: quantityControllers ?? this.quantityControllers,
      selectedUnits: selectedUnits ?? this.selectedUnits,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PreparationController extends StateNotifier<PreparationState> {
  PreparationController(this.ref) : super(const PreparationState());
  final Ref ref;

  void toggleTask(String taskId, bool isSelected) {
    final newControllers = Map<String, TextEditingController>.from(state.quantityControllers);
    if (isSelected && !newControllers.containsKey(taskId)) {
      newControllers[taskId] = TextEditingController();
    } else if (!isSelected) {
      newControllers.remove(taskId)?.dispose();
    }

    state = state.copyWith(
      selectedTasks: {...state.selectedTasks, taskId: isSelected},
      quantityControllers: newControllers,
    );
  }

  void updateNote(String taskId, String note) {
    state = state.copyWith(taskNotes: {...state.taskNotes, taskId: note});
  }

  void updateUnit(String taskId, String? unitId) {
    state = state.copyWith(selectedUnits: {...state.selectedUnits, taskId: unitId});
  }

  @override
  void dispose() {
    for (var controller in state.quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String?> generateLists(DateTime forDate) async {
    state = state.copyWith(isLoading: true);
    final firestore = ref.read(firestoreProvider);
    final dateId = DateFormat('yyyy-MM-dd').format(forDate);
    final batch = firestore.batch();

    try {
      for (final taskId in state.selectedTasks.keys) {
        if (state.selectedTasks[taskId] == true) {
          final taskDoc = await firestore.collection('prepTasks').doc(taskId).get();
          if (taskDoc.exists) {
            final taskData = taskDoc.data() as Map<String, dynamic>;
            final quantity = num.tryParse(state.quantityControllers[taskId]?.text ?? '0') ?? 0;
            final unitId = state.selectedUnits[taskId];
            
            final dailyTaskRef = firestore.collection('dailyTodoLists').doc(dateId).collection('prepTasks').doc();
            batch.set(dailyTaskRef, {
              ...taskData,
              'originalTaskId': taskId,
              'isCompleted': false,
              'note': state.taskNotes[taskId] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'plannedQuantity': quantity,
              'completedQuantity': 0,
              'unit': unitId != null ? firestore.collection('units').doc(unitId) : null,
            });
          }
        }
      }
      await batch.commit();
      state = state.copyWith(isLoading: false, selectedTasks: {}, taskNotes: {}, quantityControllers: {});
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString();
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

final prepTasksCountProvider = StreamProvider.autoDispose.family<int, String>((ref, date) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('dailyTodoLists')
      .doc(date)
      .collection('prepTasks')
      .where('isCompleted', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final isViewingAsStaffProvider = StateProvider<bool>((ref) => false);

final pendingSuggestionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  debugPrint("[Provider] Listening to dailyOrderingSuggestions for date: $today");

  return firestore
      .collection('dailyOrderingSuggestions')
      .doc(today)
      .collection('suggestions')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        debugPrint("[Provider] Received snapshot with ${snapshot.docs.length} documents.");
        return snapshot.docs.length;
      });
});

final orderedSuggestionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  // This provider needs to scan all daily suggestion documents, which is less efficient
  // but necessary to find all 'ordered' items across different days.
  // A more optimized approach might involve a separate root collection for orders.
  return firestore
      .collectionGroup('suggestions')
      .where('status', isEqualTo: 'ordered')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final masterMiseEnPlaceProvider = StreamProvider.autoDispose<Map<String, List<PrepTask>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final activeDishesStream = firestore
      .collection('dishes')
      .where('isComponent', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .snapshots();

  final dailyCompletionStream = firestore
      .collection('dailyCompletedTasks')
      .doc(today)
      .collection('tasks')
      .snapshots();

  return Rx.combineLatest2(activeDishesStream, dailyCompletionStream, 
      (QuerySnapshot dishesSnapshot, QuerySnapshot completionSnapshot) async {
    
    final completionMap = {for (var doc in completionSnapshot.docs) doc.id: doc.data() as Map<String, dynamic>};
    final allComponents = <String, PrepTask>{};

    for (final dishDoc in dishesSnapshot.docs) {
      final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unknown Dish';
      final prepTasksSnapshot = await dishDoc.reference.collection('prepTasks').get();

      for (final prepTaskDoc in prepTasksSnapshot.docs) {
        final componentData = prepTaskDoc.data();
        final linkedDishRef = componentData['linkedDishRef'] as DocumentReference?;

        if (linkedDishRef != null) {
          final componentDoc = await linkedDishRef.get();
          if (componentDoc.exists) {
            final componentMasterData = componentDoc.data() as Map<String, dynamic>;
            final isGloballyActive = componentMasterData['isGloballyActive'] ?? false;

            if (isGloballyActive) {
              final completedInfo = completionMap[linkedDishRef.id];
              final existingTask = allComponents[linkedDishRef.id];

              if (existingTask != null) {
                final updatedParentDishes = List<String>.from(existingTask.parentDishes)..add(dishName);
                allComponents[linkedDishRef.id] = existingTask.copyWith(
                  parentDishes: updatedParentDishes,
                  isCompleted: completedInfo?['isCompleted'] ?? false,
                  completedBy: completedInfo?['completedBy'] as String?,
                  completedAt: (completedInfo?['completedAt'] as Timestamp?)?.toDate(),
                );
              } else {
                allComponents[linkedDishRef.id] = PrepTask(
                  id: linkedDishRef.id,
                  taskName: componentMasterData['dishName'] ?? 'Unnamed Component',
                  station: componentMasterData['station'] ?? 'Unassigned',
                  isCompleted: completedInfo?['isCompleted'] ?? false,
                  completedBy: completedInfo?['completedBy'] as String?,
                  completedAt: (completedInfo?['completedAt'] as Timestamp?)?.toDate(),
                  parentDishes: [dishName],
                  order: 0,
                );
              }
            }
          }
        }
      }
    }
    return groupBy(allComponents.values.toList(), (task) => task.station ?? 'Unassigned');
  }).asyncMap((event) async => await event);
});

final miseEnPlaceProvider = FutureProvider.autoDispose<List<Dish>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // 1. Get today's completion data for all tasks
  final completionSnapshot = await firestore.collection('dailyCompletedTasks').doc(today).collection('tasks').get();
  final completionData = {for (var doc in completionSnapshot.docs) doc.id: doc.data()};

  // 2. Get all active dishes that are NOT components
  final activeDishesSnapshot = await firestore
      .collection('dishes')
      .where('isActive', isEqualTo: true)
      .where('isComponent', isEqualTo: false) // <-- THE CRITICAL FIX
      .get();

  final List<Dish> dishesWithTasks = [];

  // 3. For each active dish, fetch its components (prep tasks)
  for (final dishDoc in activeDishesSnapshot.docs) {
    final dishData = dishDoc.data();
    final dish = Dish.fromFirestore(dishData, dishDoc.id);

    final prepTasksSnapshot = await dishDoc.reference.collection('prepTasks').orderBy('order').get();

    final List<PrepTask> tasksForThisDish = [];
    for (final prepTaskDoc in prepTasksSnapshot.docs) {
      final task = PrepTask.fromFirestore(prepTaskDoc.data(), prepTaskDoc.id);
      final completedInfo = completionData[task.id];

      // Create the final task object, combining master data with today's progress
      final updatedTask = task.copyWith(
        completedQuantity: (completedInfo?['completedQuantity'] ?? 0) as num,
      );
      tasksForThisDish.add(updatedTask);
    }

    // Create a new Dish object that contains only its own prep tasks
    final finalDish = dish.copyWith(prepTasks: tasksForThisDish);
    dishesWithTasks.add(finalDish);
  }

  return dishesWithTasks;
});

final dailyCompletionProvider = StreamProvider.autoDispose.family<Map<String, Map<String, dynamic>>, String>((ref, dateId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('dailyCompletedTasks').doc(dateId).collection('tasks').snapshots().map((snapshot) {
    return {for (var doc in snapshot.docs) doc.id: doc.data()};
  });
});

final receivedSuggestionsProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collectionGroup('suggestions')
      .where('status', isEqualTo: 'received')
      .orderBy('createdAt', descending: true)
      .snapshots();
});


// ==== Notification and Request Providers ====
final newBarRequestsProvider = StreamProvider.autoDispose<List<DocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final currentStaffDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return firestore.collection('dailyTodoLists').doc(currentStaffDate).collection('barRequests').where('isCompleted', isEqualTo: false).snapshots().map((snapshot) => snapshot.docs);
});

// In lib/providers.dart, after the 'openRequisitionsProvider'

// Provider to fetch only requisitions that are ready for pickup.
final preparedRequisitionsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('requisitions')
      .where('status', isEqualTo: 'prepared')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// In lib/providers.dart

// ... (other providers)

// Provider to count only the 'prepared' requisitions.
final preparedRequisitionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  // We watch the .stream of the other provider to get the raw stream,
  // then we map its length to create a new Stream<int>.
  final preparedStream = ref.watch(preparedRequisitionsProvider.stream);
  return preparedStream.map((snapshot) => snapshot.length);
});

// ... (rest of the file)

final tomorrowsFloorStaffPrepTasksProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final tomorrowFormattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
  return firestore
      .collection('dailyTodoLists')
      .doc(tomorrowFormattedDate)
      .collection('prepTasks')
      .where('category', isEqualTo: 'Floor Staff Report')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc['originalFloorChecklistItemId'] as String).toSet());
});

// This is the correct provider that uses the new grouped requisition model.
final openRequisitionsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('requisitions')
      .where('status', whereIn: ['requested', 'prepared'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// This provider counts the requisitions from the new model.
final openRequisitionsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('requisitions')
      .where('status', whereIn: ['requested', 'prepared'])
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

// ==== REQUISITION HISTORY PROVIDER (THE FIX) ====
final requisitionHistoryProvider = StreamProvider.autoDispose<List<Requisition>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('requisitions')
      .where('status', isEqualTo: 'received') // <-- THE ONLY CHANGE NEEDED
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Requisition.fromFirestore(doc)).toList());
});
// ===============================================

// Provider to fetch all components for the management screen
final allComponentsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  return ref.watch(firestoreProvider)
      .collection('dishes')
      .where('isComponent', isEqualTo: true)
      .orderBy('dishName')
      .snapshots();
});

// NEW ENUM for the bell status
enum RequisitionStatus { none, requested, prepared }

// UPDATED PROVIDER for the blinking bell logic
final openRequisitionStatusProvider = StreamProvider.autoDispose<RequisitionStatus>((ref) {
  final openReqsStream = ref.watch(openRequisitionsProvider.stream);
  final barReqsStream = ref.watch(newBarRequestsProvider.stream);

  return Rx.combineLatest2(
    openReqsStream,
    barReqsStream,
        (List<DocumentSnapshot> requisitions, List<DocumentSnapshot> barRequests) {
      if (barRequests.isNotEmpty) {
        // If there are any open bar requests, the status is always 'requested'.
        return RequisitionStatus.requested;
      }

      if (requisitions.isEmpty) {
        return RequisitionStatus.none;
      }

      // If any requisition has the status 'requested', that's our highest priority.
      if (requisitions.any((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'requested')) {
        return RequisitionStatus.requested;
      }

      // Otherwise, if there are any 'prepared' requisitions, that's the status.
      if (requisitions.any((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'prepared')) {
        return RequisitionStatus.prepared;
      }

      return RequisitionStatus.none;
    },
  );
});

// ==== Analytics Providers ====
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
    // ...
    return [];
  }
  Future<List<TaskChampion>> getTaskCompletionStats({ required DateTime startDate, required DateTime endDate, }) async {
    // ...
    return [];
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

@immutable
class ButcherAnalytics {
  final List<AnalyzedIngredient> topFiveItems;
  const ButcherAnalytics({required this.topFiveItems});
}

final butcherAnalyticsProvider = FutureProvider.autoDispose<ButcherAnalytics>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(appUserProvider).value;

  if (user == null) {
    return const ButcherAnalytics(topFiveItems: []);
  }

  final requisitionsSnapshot = await firestore
      .collection('requisitions')
      .where('userId', isEqualTo: user.uid)
      .where('department', isEqualTo: 'butcher')
      .get();

  if (requisitionsSnapshot.docs.isEmpty) {
    return const ButcherAnalytics(topFiveItems: []);
  }

  final itemCounts = <String, ({num quantity, String unit})>{};

  for (final doc in requisitionsSnapshot.docs) {
    final data = doc.data();
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    for (final item in items) {
      final itemName = item['itemName'] as String;
      final quantity = item['quantity'] as num;
      final unit = item['unit'] as String? ?? 'N/A';

      itemCounts.update(
        itemName,
        (value) => (quantity: value.quantity + quantity, unit: value.unit),
        ifAbsent: () => (quantity: quantity, unit: unit),
      );
    }
  }

  final sortedItems = itemCounts.entries.toList()
    ..sort((a, b) => b.value.quantity.compareTo(a.value.quantity));

  final topItems = sortedItems.take(5).map((entry) {
    return AnalyzedIngredient(
      name: entry.key,
      totalQuantity: entry.value.quantity,
      unit: entry.value.unit,
    );
  }).toList();

  return ButcherAnalytics(topFiveItems: topItems);
});
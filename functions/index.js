const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/*
  Add any other existing Cloud Functions you have here.
*/

/**
 * Triggered when a new document is created in any 'stockRequisitions' subcollection.
 * This function creates a corresponding in-app notification for all users
 * with the role 'Kitchen Staff' or 'Admin'.
 */
exports.onRequisitionCreate_createInAppNotification = functions.firestore
    .document("dailyTodoLists/{date}/stockRequisitions/{reqId}")
    .onCreate(async (snapshot, context) => {
      const requisitionData = snapshot.data();
      const taskName = requisitionData.taskName || "A new item";

      // 1. Get all users who are Kitchen Staff or Admins
      const usersSnapshot = await admin.firestore().collection("users")
          .where("role", "in", ["Kitchen Staff", "Admin"])
          .get();

      if (usersSnapshot.empty) {
        console.log("No kitchen staff or admins found to notify.");
        return;
      }

      // 2. Create a notification document for each user in a batch
      const batch = admin.firestore().batch();
      usersSnapshot.forEach((userDoc) => {
        const userId = userDoc.id;
        const notificationRef = admin.firestore()
            .collection("users").doc(userId)
            .collection("notifications").doc(); // Creates a new notification with a unique ID

        batch.set(notificationRef, {
          title: "New Butcher Requisition",
          body: `Request for ${taskName}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          relatedRequisitionId: snapshot.id, // Optional: Link to the original request
        });
      });

      // 3. Commit the batch write to Firestore
      try {
        await batch.commit();
        console.log(`Notifications created for ${usersSnapshot.size} users.`);
      } catch (error) {
        console.error("Error creating notifications in batch:", error);
      }
    });
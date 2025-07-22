const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require('nodemailer');
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

/**
 * Callable function to send a purchase order email to a supplier.
 *
 * @param {object} data - The data passed to the function.
 * @param {string} data.recipientEmail - The email address of the supplier.
 * @param {string} data.subject - The subject of the email.
 * @param {string} data.body - The HTML body of the email.
 * @param {functions.https.CallableContext} context - The context of the function call.
 * @returns {Promise<{success: boolean}>} - A promise that resolves with a success status.
 */
exports.sendOrderEmail = functions.https.onCall(async (data, context) => {
  // TODO: Configure these environment variables in your Firebase project settings.
  // `firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-app-password"`
  const gmailEmail = functions.config().gmail.email;
  const gmailPassword = functions.config().gmail.password;

  if (!gmailEmail || !gmailPassword) {
    console.error("Gmail credentials are not configured. Please set gmail.email and gmail.password config.");
    throw new functions.https.HttpsError('internal', 'The email service is not configured.');
  }

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: gmailEmail,
      pass: gmailPassword,
    },
  });

  const mailOptions = {
    from: `"Your App Name" <${gmailEmail}>`,
    to: data.recipientEmail,
    subject: data.subject,
    html: data.body,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log('Email sent successfully to:', data.recipientEmail);
    return { success: true };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email.', error);
  }
});

/**
 * Triggered when an inventory item is updated.
 * Checks if the stock has fallen below the minimum level and creates a daily ordering suggestion if so.
 */
exports.onInventoryUpdate_createOrderSuggestion = functions.firestore
    .document("inventoryItems/{itemId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      const newQuantity = newData.quantityOnHand || 0;
      const oldQuantity = oldData.quantityOnHand || 0;
      const minStock = newData.minStockLevel || 0;

      console.log(`Item: ${newData.itemName}, New Qty: ${newQuantity}, Old Qty: ${oldQuantity}, Min Stock: ${minStock}`);

      // Proceed only if the quantity has actually decreased and crossed the minimum stock threshold
      if (newQuantity < oldQuantity && newQuantity <= minStock) {
        console.log("Stock is below minimum, proceeding to create suggestion.");
        // Check if a suggestion for this item already exists for today to avoid duplicates
        const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD format
        const suggestionRef = admin.firestore().collection("dailyOrderingSuggestions").doc(today).collection("suggestions");
        
        const existingSuggestion = await suggestionRef.where("inventoryItemRef", "==", change.after.reference).get();

        if (existingSuggestion.empty) {
          console.log("No existing suggestion found for this item today.");
          const parLevel = newData.parLevel || 0;
          const quantityToOrder = parLevel - newQuantity;
          console.log(`Par Level: ${parLevel}, Quantity to Order: ${quantityToOrder}`);

          // Ensure we only suggest ordering a positive quantity
          if (quantityToOrder > 0) {
            const suggestionData = {
              inventoryItemRef: change.after.reference,
              itemName: newData.itemName || "Unknown Item",
              supplierRef: newData.supplier, // Assuming 'supplier' is a DocumentReference
              unitRef: newData.unit, // Assuming 'unit' is a DocumentReference
              quantityToOrder: quantityToOrder,
              status: "pending", // Initial status
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            
            console.log("Creating new suggestion:", suggestionData);
            return suggestionRef.add(suggestionData);
          } else {
            console.log("Quantity to order is not positive, skipping suggestion.");
          }
        } else {
          console.log("Suggestion for this item already exists today.");
        }
      } else {
        console.log("Conditions not met for creating a suggestion.");
      }
      return null; // No action needed
    });

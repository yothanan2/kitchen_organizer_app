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

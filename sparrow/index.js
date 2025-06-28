// sparrow/index.js
// COMBINED FILE: Contains all your functions plus the new temporary one-time admin bootstrap function.

const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
const admin = require("firebase-admin");

// Initialize the Admin SDK (it's safe to call this once at the top)
admin.initializeApp();

// --- NEW TEMPORARY FUNCTION TO MAKE YOURSELF AN ADMIN ---
/**
 * A one-time callable function to make your user account an Admin.
 * You can delete this function after you have used it once.
 */
exports.bootstrapAdmin = functions.https.onRequest(async (req, res) => {
  const targetUid = "KA5v04zo2ucb3h19qPipHpbI5Ty2"; // Your Admin UID
  const roleToSet = "Admin";

  try {
    // This sets the custom security claim on your auth user
    await admin.auth().setCustomUserClaims(targetUid, { role: roleToSet });

    // This updates the role in your Firestore document for consistency
    await admin.firestore().collection("users").doc(targetUid).update({ role: roleToSet });

    const message = `SUCCESS: User ${targetUid} has been given the role of ${roleToSet}. You should now log out and log back into your app. You can delete this function after use.`;
    functions.logger.info(message);
    res.status(200).send(message);

  } catch (error) {
    functions.logger.error("Error in bootstrapAdmin function:", error);
    res.status(500).send("An error occurred. Check the function logs.");
  }
});


// --- Your existing email configuration ---
const gmailEmail = functions.config().gmail.email;
const gmailPassword = functions.config().gmail.password;
const companyName = functions.config().company.name;

const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: gmailEmail,
        pass: gmailPassword,
    },
});

// --- Your existing email function (unchanged) ---
exports.sendOrderEmail = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
    }

    const { recipientEmail, subject, body } = data;

    const mailOptions = {
        from: `"${companyName}" <${gmailEmail}>`,
        to: recipientEmail,
        subject: subject,
        html: body,
    };

    try {
        await transporter.sendMail(mailOptions);
        return { success: true };
    } catch (error) {
        console.error("Error sending email:", error);
        throw new functions.https.HttpsError("internal","Error sending email.");
    }
});

// --- Your existing data-fixing function (unchanged) ---
exports.fixSupplierReferences = functions.https.onRequest(async (req, res) => {
    const db = admin.firestore();
    const batch = db.batch();
    let itemsToUpdate = 0;

    functions.logger.info("Starting supplier data migration script...");

    try {
        const suppliersSnapshot = await db.collection("suppliers").get();
        const supplierRefsById = new Map();
        const supplierRefsByName = new Map();
        suppliersSnapshot.forEach(doc => {
            supplierRefsById.set(doc.id, doc.ref);
            const name = doc.data().name;
            if (name) {
               supplierRefsByName.set(name.trim().toLowerCase(), doc.ref);
            }
        });
        functions.logger.info(`Found ${supplierRefsById.size} suppliers.`);

        const inventorySnapshot = await db.collection("inventoryItems").get();
        functions.logger.info(`Found ${inventorySnapshot.docs.length} total inventory items.`);

        inventorySnapshot.forEach(itemDoc => {
            const itemData = itemDoc.data();
            let correctSupplierRef = null;

            if (itemData.supplier && typeof itemData.supplier === 'string') {
                const supplierString = itemData.supplier;
                correctSupplierRef = supplierRefsById.get(supplierString) || supplierRefsByName.get(supplierString.trim().toLowerCase());
            } else if (itemData.supplierId && typeof itemData.supplierId === 'string') {
                const supplierIdString = itemData.supplierId;
                correctSupplierRef = supplierRefsById.get(supplierIdString);
            }

            if (correctSupplierRef) {
                functions.logger.info(`Fixing item: ${itemData.itemName} (ID: ${itemDoc.id})`);
                const updates = { 'supplier': correctSupplierRef, 'supplierId': admin.firestore.FieldValue.delete() };
                batch.update(itemDoc.ref, updates);
                itemsToUpdate++;
            }
        });

        if (itemsToUpdate > 0) {
            await batch.commit();
            const successMessage = `Successfully updated ${itemsToUpdate} items!`;
            functions.logger.info(successMessage);
            res.status(200).send(successMessage);
        } else {
            const noItemsMessage = "No items needed fixing.";
            functions.logger.info(noItemsMessage);
            res.status(200).send(noItemsMessage);
        }

    } catch (e) {
        functions.logger.error("An error occurred during migration:", e);
        res.status(500).send("An error occurred. Check the function logs.");
    }
});

// --- Your existing role-setting function (unchanged) ---
exports.setUserRole = functions.https.onCall(async (data, context) => {
  if (context.auth.token.role !== 'Admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set user roles.'
    );
  }

  const { uid, newRole } = data;

  if (!uid || !newRole) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The function must be called with "uid" and "newRole" arguments.'
    );
  }

  try {
    await admin.auth().setCustomUserClaims(uid, { role: newRole });
    const message = `Success! User ${uid} has been given the role of ${newRole}.`;
    functions.logger.info(message);
    return { result: message };
  } catch (error) {
    functions.logger.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError('internal', 'Unable to set custom role.');
  }
});
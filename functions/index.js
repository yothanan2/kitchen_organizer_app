// functions/index.js
// MODIFIED to add the new generateLists Cloud Function

const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
const admin = require("firebase-admin");

// Initialize the Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Configure the email transporter using your Gmail account and App Password
const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: functions.config().gmail.email,
        pass: functions.config().gmail.password,
    },
});

// This is your existing function, unchanged.
exports.sendOrderEmail = functions.https.onCall(async (data, context) => {
    const { recipientEmail, subject, body } = data;

    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
    }

    const mailOptions = {
        from: "unmercato@gmail.com",
        to: recipientEmail,
        subject: subject,
        html: body,
    };

    try {
        await transporter.sendMail(mailOptions);
        return { success: true, message: "Email sent successfully!" };
    } catch (error) {
        console.error("There was an error sending the email:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Error sending email.",
        );
    }
});

// --- THIS IS THE NEW FUNCTION ---
// It runs in the europe-west1 region and has 512MB of memory allocated.
exports.generateLists = functions.region('europe-west1').runWith({ memory: '512MB' }).https.onCall(async (data, context) => {
    // 1. Authentication Check
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "You must be logged in to generate lists.");
    }

    // 2. Get Data from App
    const { dateString, selectedDishRefs } = data; // Expects a date and a list of dish references
    if (!dateString) {
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'dateString'.");
    }

    const dailyListRef = db.collection('dailyTodoLists').doc(dateString);
    const batch = db.batch();

    try {
        // 3. Clear existing tasks for that day to prevent duplicates
        console.log(`Clearing tasks for ${dateString}...`);
        const oldPrepTasks = await dailyListRef.collection('prepTasks').get();
        oldPrepTasks.forEach(doc => batch.delete(doc.ref));

        const oldStockTasks = await dailyListRef.collection('stockRequisitions').get();
        oldStockTasks.forEach(doc => batch.delete(doc.ref));

        // 4. Create the main daily list document
        batch.set(dailyListRef, {
            date: dateString,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: context.auth.token.name || 'Unknown User'
        }, { merge: true });

        // 5. Add tasks from selected dishes (if any are passed)
        if (selectedDishRefs && Array.isArray(selectedDishRefs)) {
            console.log(`Adding tasks for ${selectedDishRefs.length} selected dishes...`);
            for (const dishPath of selectedDishRefs) {
                const dishRef = db.doc(dishPath); // Recreate reference from path
                const dishDoc = await dishRef.get();

                if (dishDoc.exists) {
                    const dishData = dishDoc.data();
                    const prepTasksSnapshot = await dishRef.collection('prepTasks').get();
                    prepTasksSnapshot.forEach(taskDoc => {
                        const taskData = taskDoc.data();
                        const targetCollection = taskData.isStockRequisition ? 'stockRequisitions' : 'prepTasks';
                        const newTaskRef = dailyListRef.collection(targetCollection).doc();
                        batch.set(newTaskRef, {
                            ...taskData,
                            dishName: dishData.dishName,
                            isCompleted: false,
                            createdAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                    });
                }
            }
        }

        // 6. Add tasks from the Bar/Floor checklist
        console.log('Adding tasks from floor_checklist_items...');
        const floorItemsSnapshot = await db.collection('floor_checklist_items').orderBy('order').get();
        floorItemsSnapshot.forEach(doc => {
            const itemData = doc.data();
            const newPrepTaskRef = dailyListRef.collection('prepTasks').doc();
            batch.set(newPrepTaskRef, {
                taskName: itemData.name,
                isCompleted: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                note: '',
                dishName: 'Bar', // Grouping name
                category: 'Bar'  // Crucial field for the UI
            });
        });

        // 7. Commit all the changes to the database
        await batch.commit();
        console.log("Successfully generated all lists.");
        return { success: true, message: "Lists generated successfully." };

    } catch (error) {
        console.error("Error generating lists:", error);
        throw new functions.https.HttpsError("internal", "Failed to generate lists.", error.message);
    }
});
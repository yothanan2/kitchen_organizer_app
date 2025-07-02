const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Your existing setUserRole function should be here...
exports.setUserRole = functions.https.onCall(async (data, context) => {
  // ... all the code for setUserRole
});

// Your existing sendOrderEmail function should be here...
exports.sendOrderEmail = functions.https.onCall(async (data, context) => {
  // ... all the code for sendOrderEmail
});

// Your other existing functions (bootstrapAdmin, fixSupplierReferences) here...


// Paste the NEW function at the end of the file
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // ... all the code for deleteUser
});
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Trigger function when a new event is created
exports.sendEventNotification = functions.firestore
  .document('groups/{groupId}/events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const groupId = context.params.groupId;
    const eventName = event.name;
    const eventDate = event.date;
    
    // Get all members of the group who are potential event participants
    const groupSnapshot = await admin.firestore().collection('groups').doc(groupId).get();
    const groupMembers = groupSnapshot.data()['members']; // Assuming 'members' is a list of user IDs

    const tokens = [];
    for (const member of groupMembers) {
      const userSnapshot = await admin.firestore().collection('users').doc(member).get();
      const token = userSnapshot.data()['fcmToken']; // Assuming the user's FCM token is stored in Firestore
      if (token) {
        tokens.push(token);
      }
    }

    // Send push notification
    const payload = {
      notification: {
        title: 'New Event Created!',
        body: 'A new event "' + eventName + '" has been created for ' + eventDate + '.',
      },
    };

    // Send notification only if there are valid tokens
    if (tokens.length > 0) {
      await admin.messaging().sendToDevice(tokens, payload);
    }

    return null;
  });

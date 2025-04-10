/* eslint-env node */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { cleanupExpiredEvents } = require("./cleanupEvents");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export cleanup function
exports.cleanupExpiredEvents = cleanupExpiredEvents;

exports.sendNewEventNotification = onDocumentCreated("events/{eventId}", async (event) => {
  // event.data contains the newly created document data.
  const eventData = event.data?.data(); // Ensure event data is retrieved correctly
  if (!eventData) {
    console.error("No event data found.");
    return;
  }

  const groupId = eventData.groupId;
  const eventTitle = eventData.title || "Untitled Event";

  if (!groupId) {
    console.error("Event does not have a valid groupId.");
    return;
  }

  console.log(`New event created for group: ${groupId}`);

  try {
    // Retrieve group document
    const groupSnap = await admin.firestore().collection("groups").doc(groupId).get();
    if (!groupSnap.exists) {
      console.log("Group not found");
      return;
    }

    const groupData = groupSnap.data();
    const memberIds = groupData.members || [];
    console.log(`Found ${memberIds.length} member(s) in group`);

    // Collect push tokens for each member
    let tokens = [];
    const promises = memberIds.map(async (memberId) => {
      const userSnap = await admin.firestore().collection("users").doc(memberId).get();
      if (userSnap.exists) {
        const userData = userSnap.data();
        if (userData.pushToken) {
          tokens.push(userData.pushToken);
        }
      }
    });
    await Promise.all(promises);

    if (tokens.length === 0) {
      console.log("No push tokens available");
      return;
    }

    // Prepare the notification payload
    const payload = {
      notification: {
        title: "New Event Created!",
        body: `Check out the new event: ${eventTitle}`,
        sound: "default"
      },
      data: {
        eventId: event.params.eventId,
        groupId: groupId
      }
    };

    // Send the notification
    const response = await admin.messaging().sendToDevice(tokens, payload);
    console.log("Push notification sent:", response);
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
});

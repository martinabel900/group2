const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json()); // To parse JSON data from HTTP requests

// Initialize Firebase Admin SDK with your service account file
const serviceAccount = require('./service-account-file.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Endpoint to send a push notification to a device
app.post('/send-notification', (req, res) => {
  const token = req.body.token; // FCM token from the client
  const message = {
    notification: {
      title: 'Hello!',
      body: 'You have a new message.',
    },
    token: token, // The FCM token to send the notification to
  };

  admin.messaging().send(message)
    .then((response) => {
      console.log('Message sent successfully:', response);
      res.status(200).send('Notification sent successfully!');
    })
    .catch((error) => {
      console.error('Error sending message:', error);
      res.status(500).send('Error sending notification.');
    });
});

// Start the server
app.listen(3000, () => {
  console.log('Server is running on port 3000');
});

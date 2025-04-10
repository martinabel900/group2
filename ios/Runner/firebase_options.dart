import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// This file is generated with the FlutterFire CLI using the command:
///   flutterfire configure
///
/// Replace the placeholder values below with your actual Firebase project configuration.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'YOUR_API_KEY', // e.g., AIzaSyA...
      appId: 'YOUR_APP_ID', // e.g., 1:1234567890:ios:abcdef123456
      messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', // e.g., 1234567890
      projectId: 'YOUR_PROJECT_ID', // e.g., my-firebase-project
      storageBucket: 'YOUR_STORAGE_BUCKET', // e.g., my-firebase-project.appspot.com
      // Optionally add measurementId if needed:
      // measurementId: 'YOUR_MEASUREMENT_ID',
    );
  }
}
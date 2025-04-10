import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// For Google sign in implementation:
import 'package:google_sign_in/google_sign_in.dart';

// For Apple sign in implementation:
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs up a new user using email, password, name, and phone number.
  /// Sets isAdmin to true and initializes the authProviders array with ['password'].
  Future<UserCredential?> signUp(String email, String password, String name, String phone) async {
  try {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User? user = userCredential.user;
    if (user != null) {
      // Update the Firebase user's displayName so that it matches the provided name.
      await user.updateDisplayName(name);
      await user.reload(); // Reload to ensure the changes take effect.
      
      // Create a user document with the required info.
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'isAdmin': true, // Should be true for new registrations
        'createdAt': FieldValue.serverTimestamp(),
        'authProviders': ['password'],
      });
    }
    return userCredential;
  } catch (e) {
    debugPrint("Error during sign up: $e");
    return null;
  }
}

  /// Signs in an existing user using email and password.
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("Error during sign in: $e");
      rethrow;
    }
  }

  /// Signs in using Google.
  /// Assumes the user registered using email/password.
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      if (_auth.currentUser != null) {
        // Link the Google credential to the current user.
        UserCredential linkedCredential = await _auth.currentUser!.linkWithCredential(credential);
        await _firestore.collection("users").doc(_auth.currentUser!.uid).update({
          "authProviders": FieldValue.arrayUnion(["google"]),
        });
        return linkedCredential;
      } else {
        // No active session: sign in normally.
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;
        if (user != null) {
          final QuerySnapshot querySnapshot = await _firestore
              .collection("users")
              .where("email", isEqualTo: user.email)
              .limit(1)
              .get();
          if (querySnapshot.docs.isEmpty) {
            throw FirebaseAuthException(
              code: 'ERROR_USER_NOT_REGISTERED',
              message: 'User must register first using email and password.',
            );
          }
          await _firestore.collection("users").doc(querySnapshot.docs.first.id).update({
            "authProviders": FieldValue.arrayUnion(["google"]),
          });
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint("Error during Google sign in: $e");
      rethrow;
    }
  }

  /// Signs in using Apple.
  /// Ensures that the email used for registration matches the one provided by Apple.
  Future<UserCredential> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final OAuthCredential oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      if (_auth.currentUser != null) {
        // Link the Apple credential.
        UserCredential linkedCredential = await _auth.currentUser!.linkWithCredential(oauthCredential);
        await _firestore.collection("users").doc(_auth.currentUser!.uid).update({
          "authProviders": FieldValue.arrayUnion(["apple"]),
        });
        return linkedCredential;
      } else {
        UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
        final User? user = userCredential.user;
        if (user != null) {
          String? emailToMatch = appleCredential.email ?? user.email;
          if (emailToMatch == null) {
            throw FirebaseAuthException(
              code: 'ERROR_NO_EMAIL',
              message: 'No email provided by Apple and current user email is null.',
            );
          }
          final QuerySnapshot querySnapshot = await _firestore
              .collection("users")
              .where("email", isEqualTo: emailToMatch)
              .limit(1)
              .get();
          if (querySnapshot.docs.isEmpty) {
            throw FirebaseAuthException(
              code: 'ERROR_USER_NOT_REGISTERED',
              message: 'User must register first using email and password.',
            );
          }
          await _firestore.collection("users").doc(querySnapshot.docs.first.id).update({
            "authProviders": FieldValue.arrayUnion(["apple"]),
          });
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint("Error during Apple sign in: $e");
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Error during sign out: $e");
      rethrow;
    }
  }
}

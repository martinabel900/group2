import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialLoginButtons extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onGoogleSignIn;
  final VoidCallback? onAppleSignIn;

  const SocialLoginButtons({
    Key? key,
    required this.isProcessing,
    required this.onGoogleSignIn,
    this.onAppleSignIn,
  }) : super(key: key);

  ButtonStyle _buildButtonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 2,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: borderColor != null
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // Google Sign-In Button (Sleek Design)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth - 32),
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : onGoogleSignIn,
            icon: const FaIcon(
              FontAwesomeIcons.google,
              size: 18,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Sign in with Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: _buildButtonStyle(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              borderColor: Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Apple Sign-In Button (Only on iOS)
        if (Platform.isIOS && onAppleSignIn != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: screenWidth - 32),
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : onAppleSignIn,
              icon: const FaIcon(
                FontAwesomeIcons.apple,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Sign in with Apple',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: _buildButtonStyle(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
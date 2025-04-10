import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'group_list.dart'; // Replace with your main application screen.

class SocialLinkingScreen extends StatefulWidget {
  const SocialLinkingScreen({Key? key}) : super(key: key);
  
  @override
  _SocialLinkingScreenState createState() => _SocialLinkingScreenState();
}

class _SocialLinkingScreenState extends State<SocialLinkingScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  
  Future<void> _linkGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authService.signInWithGoogle();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google account linked")),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _linkApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authService.signInWithApple();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Apple account linked")),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect Social Accounts"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Connect Social Accounts",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _linkGoogle,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle),
                      ),
                      label: const Text("Link with Google"),
                    ),
              const SizedBox(height: 16),
              _isLoading
                  ? Container()
                  : ElevatedButton.icon(
                      onPressed: _linkApple,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.apple, size: 24),
                      label: const Text("Link with Apple"),
                    ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Once linking is complete, navigate to your main app (e.g., GroupListScreen).
                  // Make sure to pass the current user's details as needed.
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => GroupListScreen(userId: "CURRENT_USER_ID", userName: "CURRENT_USER_NAME")),
                  );
                },
                child: const Text("Continue to App"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
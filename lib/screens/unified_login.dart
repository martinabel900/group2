import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'social_linking.dart';
import 'group_list.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({Key? key}) : super(key: key);

  @override
  _UnifiedLoginScreenState createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Sign in using email/password.
  Future<void> _handleEmailLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final UserCredential credential = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Navigate to GroupListScreen (or your main app) upon successful sign‑in.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupListScreen(userId: credential.user!.uid, userName: credential.user!.displayName ?? _emailController.text.trim())),
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
  
  // Social sign-in using Google.
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Call the AuthService method; if the account isn’t linked, it may throw an error.
      final UserCredential credential = await _authService.signInWithGoogle();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupListScreen(userId: credential.user!.uid, userName: credential.user!.displayName ?? '')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Social sign-in using Apple.
  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final UserCredential credential = await _authService.signInWithApple();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupListScreen(userId: credential.user!.uid, userName: credential.user!.displayName ?? '')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose(){
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unified Login"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Sign in",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Email/Password Section
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleEmailLogin,
                      child: const Text("Login with Email"),
                    ),
              const SizedBox(height: 24),
              // Or sign in with social providers.
              Text(
                "Or sign in with",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? Container()
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: _handleGoogleLogin,
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle),
                      ),
                      label: const Text("Google"),
                    ),
              const SizedBox(height: 16),
              _isLoading
                  ? Container()
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.black,
                      ),
                      onPressed: _handleAppleLogin,
                      icon: const Icon(Icons.apple, size: 24),
                      label: const Text("Apple"),
                    ),
              const SizedBox(height: 24),
              // Optionally, add a button to go to the linking page if needed.
              TextButton(
                  onPressed: () {
                    // Navigate to social linking (if you want to force linking)
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SocialLinkingScreen()),
                    );
                  },
                  child: const Text("Link additional accounts", style: TextStyle(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }
}
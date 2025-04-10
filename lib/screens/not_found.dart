import 'package:flutter/material.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Found'),
      ),
      body: Center(
        child: const Text(
          'Oops! The page you are looking for does not exist.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

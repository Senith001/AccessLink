import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        title: const Text('Home'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Welcome to AccessLink',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
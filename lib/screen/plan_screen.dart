import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: true,
        title: Text('Ai Travel Plan', style: TextStyle(fontSize: 24)),
      ),
      body: Center(
        child: Text('This is the Ai Travel Plan screen.'),
      ),
    );

  }
}
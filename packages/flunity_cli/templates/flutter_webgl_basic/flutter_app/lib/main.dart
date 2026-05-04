import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

void main() {
  registerBuiltInMessages();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '__app_name__',
      home: Scaffold(
        appBar: AppBar(title: const Text('__app_name__')),
        body: const Center(
            child: Text('Flunity scaffold — wire up FlunityWebGLView next.')),
      ),
    );
  }
}

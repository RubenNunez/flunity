import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

import 'unity/unity_webgl_screen.dart';

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
      home: const UnityWebGLScreen(),
    );
  }
}

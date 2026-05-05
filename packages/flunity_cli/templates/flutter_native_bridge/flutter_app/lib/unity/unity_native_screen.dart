import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

import 'unity_native_bridge.dart';

class UnityNativeScreen extends StatefulWidget {
  const UnityNativeScreen({super.key});

  @override
  State<UnityNativeScreen> createState() => _UnityNativeScreenState();
}

class _UnityNativeScreenState extends State<UnityNativeScreen> {
  String _lastEvent = 'Waiting…';

  void _onMessageFromUnity(String raw) {
    final msg = UnityNativeBridge.tryParse(raw);
    if (msg != null) {
      setState(() => _lastEvent = msg.type);
    } else {
      setState(() => _lastEvent = 'raw: ${raw.length} chars');
    }
  }

  Future<void> _ping() async {
    try {
      final nonce = await UnityNativeBridge.ping();
      setState(() => _lastEvent = 'Ping sent: $nonce');
    } catch (e) {
      setState(() => _lastEvent = 'Ping failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('__app_name__'),
        actions: [
          IconButton(
            tooltip: 'Ping',
            onPressed: _ping,
            icon: const Icon(Icons.network_ping),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlunityNativeView(onMessageFromUnity: _onMessageFromUnity),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastEvent,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

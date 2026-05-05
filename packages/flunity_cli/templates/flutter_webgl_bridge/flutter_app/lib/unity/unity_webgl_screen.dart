import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

import 'unity_webgl_bridge.dart';
import 'unity_webgl_config.dart';

class UnityWebGLScreen extends StatefulWidget {
  const UnityWebGLScreen({super.key});

  @override
  State<UnityWebGLScreen> createState() => _UnityWebGLScreenState();
}

class _UnityWebGLScreenState extends State<UnityWebGLScreen> {
  UnityWebGLBridge? _bridge;
  String _lastEvent = 'Waiting…';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('__app_name__'),
        actions: [
          IconButton(
            tooltip: 'Ping',
            onPressed: _bridge == null ? null : () async {
              try {
                final nonce = await _bridge!.ping();
                setState(() => _lastEvent = 'Pong: $nonce');
              } catch (e) {
                setState(() => _lastEvent = 'Ping failed: $e');
              }
            },
            icon: const Icon(Icons.network_ping),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlunityWebGLView(
            config: resolveFlunityConfig(),
            onReady: (controller) {
              setState(() => _bridge = UnityWebGLBridge(controller));
            },
            onMessage: (msg) {
              setState(() => _lastEvent = msg.type);
            },
          ),
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
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

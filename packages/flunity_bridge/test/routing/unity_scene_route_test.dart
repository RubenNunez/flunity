import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sends LoadScene on mount', (tester) async {
    final sent = <FlunityMessage>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UnitySceneRoute(
          scene: 'menu',
          send: (msg) async => sent.add(msg),
          child: const SizedBox(),
        ),
      ),
    );

    // Microtask scheduled in initState fires on the next pump.
    await tester.pump();
    expect(sent, [const LoadScene(scene: 'menu')]);
  });

  testWidgets('sends a new LoadScene when the scene prop changes', (
    tester,
  ) async {
    final sent = <FlunityMessage>[];

    Widget build(String scene) => MaterialApp(
      home: UnitySceneRoute(
        scene: scene,
        send: (msg) async => sent.add(msg),
        child: const SizedBox(),
      ),
    );

    await tester.pumpWidget(build('menu'));
    await tester.pump();

    await tester.pumpWidget(build('game'));
    await tester.pump();

    expect(sent, [
      const LoadScene(scene: 'menu'),
      const LoadScene(scene: 'game'),
    ]);
  });

  testWidgets('restores previousScene on dispose', (tester) async {
    final sent = <FlunityMessage>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UnitySceneRoute(
          scene: 'detail',
          previousScene: 'menu',
          send: (msg) async => sent.add(msg),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    // Replace with an unrelated tree → first widget gets disposed.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(sent, [
      const LoadScene(scene: 'detail'),
      const LoadScene(scene: 'menu'),
    ]);
  });

  testWidgets('does NOT restore when previousScene is null', (tester) async {
    final sent = <FlunityMessage>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UnitySceneRoute(
          scene: 'detail',
          send: (msg) async => sent.add(msg),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(sent, [const LoadScene(scene: 'detail')]);
  });
}

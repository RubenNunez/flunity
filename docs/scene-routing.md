# Scene routing: one Unity, many Flutter routes

The naive Flutter pattern is "mount `FlunityNativeView` (or `FlunityWebGLView`) inside each route that needs Unity". This works but is wasteful: each route push tears down Unity and re-instantiates it, dropping all in-Unity state and incurring a 1–3 second cold-start hitch.

Flunity ships `UnitySceneRoute` to support a different pattern: **mount Unity once at the app shell, then swap Unity scenes as Flutter routes change.**

## The pattern

```dart
// At the app root — Unity stays alive across route changes.
class App extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => Stack(
        children: [
          // Unity is always mounted, just z-ordered behind your routes
          // (or sized into a slot, depending on your app shell).
          const Positioned.fill(child: FlunityNativeView()),
          if (child != null) child,
        ],
      ),
      routes: {
        '/': (_) => UnitySceneRoute.native(
              scene: 'Menu',
              child: MenuPage(),
            ),
        '/play': (_) => UnitySceneRoute.native(
              scene: 'Game',
              previousScene: 'Menu',     // restore on pop
              child: GamePage(),
            ),
        '/profile': (_) => UnitySceneRoute.native(
              scene: 'ProfileScene',
              previousScene: 'Menu',
              child: ProfilePage(),
            ),
      },
    );
  }
}
```

When you push `/play`, `UnitySceneRoute` dispatches `LoadScene(scene: 'Game')` to Unity. When the user pops back, the dispose hook fires `LoadScene(scene: 'Menu')` to restore the previous scene. Unity itself never goes through a tear-down.

## How it works

- `initState` — sends `LoadScene(scene: <new scene>)` via the `send` callback.
- `didUpdateWidget` — if the `scene` prop changes (e.g. you parametrise the route), sends a fresh `LoadScene`.
- `dispose` — if `previousScene` is non-null, sends `LoadScene(scene: <previousScene>)` so the underlying Unity instance ends in a known state.

The widget never owns a Unity instance — it's purely a route-scoped message dispatcher. This is what makes it transport-agnostic: pass any `Future<void> Function(FlunityMessage)` as `send` and it drives whatever transport you've wired up.

## Native vs WebGL

For the native template, `UnitySceneRoute.native` pre-wires `send` to:

```dart
sendToUnity('[FlunityBridge]', 'ReceiveFromFlutter', jsonEncode(message.toJson()))
```

…which matches the canonical `FlunityBridge` GameObject shipped in Phase 4's templates.

For WebGL, pass your own `send` that goes through your `FlunityWebGLController`:

```dart
UnitySceneRoute(
  scene: 'Game',
  send: (msg) => webglController.send(msg),
  child: GamePage(),
)
```

Both routes share the same `LoadScene` envelope, so Unity-side handling is identical regardless of transport.

## Caveats

- **Unity must already have the scene loaded into Build Settings.** `LoadScene("Foo")` is a no-op (with a Unity console warning) if `Foo` isn't in `EditorBuildSettings.scenes`.
- **Scene restoration runs on dispose, not on pop animation start.** There's a brief window — typically 200–300 ms during the route-pop animation — where Unity is still on the new scene. If that's visible to the user (e.g. you have a translucent app bar), nudge `previousScene` swaps with a `WillPopScope` instead.
- **If both routes set `previousScene`, you get a double-swap.** Pushing `/play` from `/profile` would dispose `/profile`'s route (sends `LoadScene("Menu")`) then mount `/play`'s route (sends `LoadScene("Game")`). The intermediate "Menu" load is wasted. Hand-roll a single `LoadScene` push when this matters.

## When NOT to use it

- **One-shot screens that need Unity briefly** — keep the per-route mount pattern. Tearing down Unity is fine if it only happens once per session.
- **Multiple Unity instances at the same time** — neither WebGL nor native supports it well; the underlying UnityPlayer / UnityFramework is a singleton.

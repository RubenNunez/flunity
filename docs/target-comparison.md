# Choosing a target: webgl vs ios vs android

There is no single right answer. This page lays out the tradeoffs honestly so you can pick.

## At a glance

| Dimension | webgl | ios | android |
| --- | --- | --- | --- |
| Flutter integration | WebView (`InAppWebView`) | UIKit `PlatformView` (UnityFramework.xcframework) | `AndroidView` (UnityPlayer Gradle module) |
| Setup overhead | Low — just Unity + Flutter | High — Xcode, signing, manual Xcode wiring | Medium — Android SDK + NDK |
| Build time (Unity, cold) | 5–15 min | 2–4 min | 1–3 min |
| Runtime perf vs native Unity | ~50–70% (varies wildly by GPU/CPU) | Native (≈100%) | Native (≈100%) |
| Bundle size impact | +20–80 MB asset bundle | +50–150 MB embedded framework | +30–100 MB unityLibrary |
| Live iteration | Hot-reloadable (Plan E) | Rebuild + bundle + flutter run | Rebuild + bundle + flutter run |
| CI complexity | Low — Unity license + Linux runner OK | High — macOS runner + signing | Medium — Linux runner + Android SDK |
| Crash / lifecycle pitfalls | Browser quirks (memory limits, audio gestures) | Activity-vs-UIViewController lifecycle, framework reloads | UnityPlayer lifecycle (configChanges, back button destroys Unity) |
| Multi-platform reach from a single artifact | Web, iOS, Android, desktop | iOS only | Android only |

## When WebGL is the right choice

- Your Unity content is **mostly UI / 2D / lightweight 3D** — menus, mini-games, dashboards, isometric scenes.
- You need to **ship to web** at all (and don't want to maintain two implementations).
- Your team has **no Apple Developer account** or no CI macOS runners.
- You want **the simplest possible iteration loop** — `flunity webgl serve` and pull-to-refresh.

WebGL is also the easiest way to demo Flunity itself: zero native setup, zero signing, zero device permissions.

## When native (iOS / Android) is the right choice

- You're shipping a **mobile-first product** with no web target.
- Your Unity content is **performance-sensitive** — particle systems, post-processing, complex shaders, 60+ fps gameplay, AR / sensor integration.
- You need **native plugins** — IAP, push notifications, AR sessions, microphone, camera intrinsics.
- You're OK paying the **CI / signing tax** in exchange for native frame rates.

A common pattern: ship iOS + Android natively, ship WebGL for marketing / demo URLs.

## When to pick **both**

You don't have to. But: if your Unity content runs well in WebGL on a modern GPU and you want a marketing landing page that demos the actual content, the WebGL build is essentially free once you've decided to ship native — you already have the Unity project, the bridge code, and the Flutter app structure. Plan G ("multi-target single project") will turn this into a one-line CLI flag; for now it's a manual `target:` swap in the manifest.

## Things people get wrong

- **"Native is always faster."** True for raw frame rate; not true if your bottleneck is the Flutter ↔ Unity bridge round-trip. Both transports use a JSON envelope of similar size. The native MethodChannel is faster than a WebView's postMessage, but if you're not sending hundreds of messages per second, the difference is invisible.
- **"WebGL bundle size is the dealbreaker."** Brotli-compressed, a tight Unity scene compresses to 5–15 MB. The 80 MB number is "shipped without compression" and is not the right number to plan with.
- **"I'll just start with WebGL and switch to native later."** This works, but be aware: native lifecycle bugs (Unity not pausing on backgrounding, iOS UnityFramework symbols not exporting) only show up when you actually flip the switch. Build a 1-day spike on the target you'll eventually ship before committing.

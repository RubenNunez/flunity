# Third-Party Code

`flunity_bridge` vendors essential native-integration code from the
[`flutter_embed_unity`](https://github.com/learntoflutter/flutter_embed_unity)
plugin instead of taking a runtime dependency on it. This file records
attribution, licenses, and the scope of what is vendored.

## flutter_embed_unity (vendored)

- **Source:** https://github.com/learntoflutter/flutter_embed_unity
- **Version:** v2.0.0
- **Tag SHA:** `32d6b2d` (commit "Updated versions to 2.0.0 stable…")
- **License:** MIT — Copyright (c) 2023 James Allen
- **Full license text:** [`THIRDPARTY-LICENSES/flutter_embed_unity-LICENSE.txt`](THIRDPARTY-LICENSES/flutter_embed_unity-LICENSE.txt)

### Sub-packages we vendor

| Upstream sub-package | Why |
| --- | --- |
| `flutter_embed_unity` | Top-level Dart wrapper API (`EmbedUnity` widget, `sendToUnity`, `pauseUnity`, `resumeUnity`, listener helpers). Becomes Flunity's `FlunityNativeView` + native-side controller. |
| `flutter_embed_unity_platform_interface` | Federated platform interface. Collapsed into `flunity_bridge`'s internal Dart structure (we don't replicate the federation pattern — one package). |
| `flutter_embed_unity_2022_3_ios` | iOS Swift implementation. Note: works for both Unity 2022.3 LTS and Unity 6 (per upstream's pubspec comment). Becomes Flunity's iOS native plugin. |
| `flutter_embed_unity_6000_0_android` | Android Kotlin implementation, Unity 6 specific. Becomes Flunity's Android native plugin. |
| `example_unity_6000_0_project/Assets/FlutterEmbed/` | Unity Editor scripts (`ProjectExporter*.cs`) for batch-building iOS / Android library exports, plus `SendToFlutter.cs` runtime helper. Vendored into the `unity_bridge_basic` template (under `Assets/Editor/Flunity/`) and the Unity-side runtime scripts already shipped. |

### Sub-packages we do NOT vendor

- `flutter_embed_unity_2022_3_android` — superseded by `_6000_0_android` (Unity 6 only is our requirement).
- `example_unity_2022_3_project` — same source as 6000_0 with minor API changes; we use the 6000_0 variant.

## Modifications to vendored code

1. **Symbol renames** — public API symbols beginning with `FlutterEmbedUnity*` /
   `EmbedUnity*` are renamed to `FlunityBridge*` / `FlunityNativeView` so users
   import from `package:flunity_bridge/...` exclusively. Method-channel names
   updated accordingly (`com.learntoflutter.flutter_embed_unity_*` →
   `com.flunity.bridge`).
2. **Federation collapsed** — the Dart-level platform-interface separation is
   replaced with a single concrete implementation inside `flunity_bridge`.
3. **Header attribution** — every vendored file carries a one-line header noting
   upstream provenance (path + commit). See `VENDOR-INVENTORY.md` for the full
   path mapping.
4. **No behavioral changes.** The runtime semantics of Unity ↔ Flutter
   messaging are unchanged from upstream.

## License compatibility

`flunity_bridge` is itself MIT (see repo-root `LICENSE`). Vendoring MIT into MIT
is compliant; we preserve the upstream copyright notice and license text in
`THIRDPARTY-LICENSES/`.

## How to refresh

When upstream releases a fix or feature we want, run the steps in
[`VENDOR-INVENTORY.md`](VENDOR-INVENTORY.md) against the new tag and produce a
diff. Most fixes will not require behavioral adaptation — Flunity's renamings
are mechanical.

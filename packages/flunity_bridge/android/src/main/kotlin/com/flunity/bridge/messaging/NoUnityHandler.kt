package com.flunity.bridge.messaging

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Stands in for [SendToUnity] when the Unity library is not in the APK
 * (WebGL-in-a-WebView builds, see `UnityAvailability`). Every call gets a
 * clear error instead of a `NoClassDefFoundError` — the Dart side treats
 * `pauseUnity` / `resumeUnity` / `sendToUnity` as best-effort anyway.
 */
class NoUnityHandler : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.error(
            "unity_unavailable",
            "Unity is not bundled in this app (no unityLibrary — a WebGL-only build); '${call.method}' has nothing to talk to.",
            null,
        )
    }
}

package com.flunity.bridge.messaging

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Stands in for [SendToUnity] when the Unity library is not in the APK
 * (a build without the Unity export, see `UnityAvailability`). Every call gets a
 * clear error instead of a `NoClassDefFoundError` — the Dart side treats
 * `pauseUnity` / `resumeUnity` / `sendToUnity` as best-effort anyway.
 */
class NoUnityHandler : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.error(
            "unity_unavailable",
            "Unity is not bundled in this app (no unityLibrary export); '${call.method}' has nothing to talk to.",
            null,
        )
    }
}

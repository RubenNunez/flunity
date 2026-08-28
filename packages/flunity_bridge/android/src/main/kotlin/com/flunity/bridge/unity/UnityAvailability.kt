package com.flunity.bridge.unity

/**
 * Whether the Unity-as-a-Library classes are in this APK at all.
 *
 * They are not in the "WebGL-in-a-WebView" setup — the Flutter app renders the
 * Unity WebGL player instead of embedding the native library (see the setup
 * matrix in the jellx docs). In that build `unityLibrary` is absent, and any
 * code that so much as resolves `com.unity3d.player.*` throws
 * `NoClassDefFoundError`. If that happens while the plugin is being constructed
 * inside `GeneratedPluginRegistrant.registerWith`, *every* plugin after it is
 * skipped: shared_preferences cannot connect, the WebView's platform view is
 * "unregistered", and the app is dead on arrival for a reason that has nothing
 * to do with those plugins (jellx, Nothing Phone, 2026-08-28).
 *
 * So the plugin never touches Unity types directly; it asks here first and
 * routes through [UnityHost].
 */
object UnityAvailability {
    val present: Boolean by lazy {
        try {
            Class.forName("com.unity3d.player.UnityPlayerForActivityOrService")
            true
        } catch (_: Throwable) {
            false
        }
    }
}

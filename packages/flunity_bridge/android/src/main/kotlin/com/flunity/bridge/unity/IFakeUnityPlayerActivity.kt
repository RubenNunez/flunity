// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.unity

/**
 * Workaround for Unity's AR features when Unity is embedded in a Flutter app.
 *
 * Some Unity subsystems (notably AR Foundation / ARCore) reach back into the
 * *Activity* they believe they are running in and expect it to expose the
 * `UnityPlayer` through a `setmUnityPlayer` setter — that is how Unity's own
 * generated `UnityPlayerActivity` is shaped. When Unity is hosted inside a
 * `FlutterActivity` instead, no such setter exists and those subsystems fail.
 *
 * A host app that uses AR can implement this interface on its Flutter
 * activity; [UnityPlayerSingleton.getOrCreateInstance] then hands the player
 * over as soon as it is created. Apps that do not use AR can ignore it — the
 * call site skips the handover when the activity does not implement this.
 *
 * NOTE: this interface was missing when the Android sources were vendored from
 * flutter_embed_unity, which made `:flunity_bridge:compileDebugKotlin` fail
 * with "Unresolved reference 'IFakeUnityPlayerActivity'" for every consumer —
 * i.e. the Android target could never build.
 */
interface IFakeUnityPlayerActivity {
    /**
     * Called with the freshly created player. Implementations normally assign
     * it to a field named `mUnityPlayer` so Unity's reflective lookups find it.
     */
    fun setmUnityPlayer(unityPlayer: UnityPlayerSingleton)
}

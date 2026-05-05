// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.platformView

import com.flunity.bridge.unity.UnityPlayerSingleton

interface IUnityViewStackable {
    fun attachUnity(unityPlayerSingleton: UnityPlayerSingleton)
    fun detachUnity()
    var onDispose: (() -> Unit)?
}
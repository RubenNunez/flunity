// Adapted from flutter_embed_unity_6000_0_android v2.0.0 (MIT, learntoflutter).
// Original: https://github.com/learntoflutter/flutter_embed_unity
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

package com.flunity.bridge.messaging

import com.flunity.bridge.constants.NativeConstants.Companion.methodNameSendToFlutter
import io.flutter.plugin.common.MethodChannel

/**
 * Static bridge invoked by Unity (via [AndroidJavaClass]) to forward a message
 * to Flutter over the [MethodChannel].
 *
 * The Unity-side helper looks like:
 * ```csharp
 * using (var nativeAPI = new AndroidJavaClass("com.flunity.bridge.messaging.SendToFlutter")) {
 *     nativeAPI.CallStatic("sendToFlutter", json);
 * }
 * ```
 */
class SendToFlutter {
    companion object {
        var methodChannel: MethodChannel? = null

        @JvmStatic
        fun sendToFlutter(data: String) {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod(methodNameSendToFlutter, data)
            } else {
                println("Couldn't send message from Unity to Flutter: method channel hasn't been initialised")
            }
        }
    }
}
